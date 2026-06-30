
abstract type DependentDNA end

abstract type ValueHolderDNA{T} <: DependentDNA end
abstract type SourceValueHolderDNA{T} <: ValueHolderDNA{T} end

abstract type SubjectDNA <: DependentDNA end
abstract type ObserverDNA{T<:SubjectDNA} end

abstract type ModelState end
struct BuildingState <: ModelState end
struct ViewingState <: ModelState end
struct EvalingState <: ModelState end

include("Nodes/subgraphs.jl")
include("Evaluation/completed_condition.jl")
include("Evaluation/goal.jl")

include("dependent_graph.jl")
include("Nodes/dependent.jl")

include("Nodes/ValueHolders/value_holder.jl")
include("Nodes/ValueHolders/generic_value_holder.jl")
include("Nodes/ValueHolders/source_value_holder.jl")
#include("Nodes/ValueHolders/unary_value_holder.jl")

include("Nodes/observer.jl")
include("Nodes/subject.jl")

include("Construction/builder.jl")
include("Construction/adder.jl")

include("Evaluation/synchronizer.jl")
include("Evaluation/evalworker.jl")
include("Evaluation/scheduler.jl")

# ? ---------------------------------
# ! Model
# ? ---------------------------------

@kwdef mutable struct Model
    _graph::DependentGraph = DependentGraph()
    _adder::Adder = Adder()
    _builder::Builder = Builder()
    _builderTask::Union{Task,Nothing} = nothing
    _scheduler::Scheduler = Scheduler()
    _workers::Workers = Workers()
    _workerTasks::Vector{Task} = Vector{Task}()
    _synchronizer::Synchronizer = Synchronizer()
end

getGraph(self::Model)::DependentGraph = self._graph
getAdder(self::Model)::Adder = self._adder
getBuilder(self::Model)::Builder = self._builder
getScheduler(self::Model)::Scheduler = self._scheduler
getWorkers(self::Model)::Workers = self._workers
getSynchronizer(self::Model)::Synchronizer = self._synchronizer

include("Construction/builder_funcs.jl")
include("Evaluation/synchronizer_funcs.jl")
include("Evaluation/evalworker_funcs.jl")
include("Evaluation/scheduler_funcs.jl")

"""
Must init the Model before use.
- Starts builder and worker tasks with errormonitors.
"""
function init!(self::Model)
    # YELLOW Thread start
    builderTask = Threads.@spawn begin
        process_until_closed!(self._builder,self)
    end
    errormonitor(builderTask)

    self._builderTask = builderTask

    for i in 1:length(self._workers)
        # RED Thread start
        workerTask = Threads.@spawn begin
            process_until_closed!(self._workers[i], self)
        end
        errormonitor(workerTask)

        push!(self._workerTasks, workerTask)
    end
end

"""
Must destroy the Model after use.
- Do not re-init this object after destroy. Construct a new one instead.
- Also waits for builder and worker tasks to close.
"""
function destroy!(self::Model)
    destroy!(self._adder)
    destroy!(self._builder)
    destroy!(self._workers)

    # YELLOW Thread end
    wait(self._builderTask)

    for workerTask in self._workerTasks
        # RED Thread end
        wait(workerTask)
    end
end

"""
Send a newly constructed Dependent to the build system of a Model.
- Adds node to the graph.
"""
function build!(self::Model, dependent::T)::T where {T<:DependentDNA}
    put!(self._builder, dependent)
    return dependent
end

"""
Send a newly constructed Subject to the build system of a Model.
- Adds node to the graph.
- An Observer for this Subject is required.
"""
function build!(self::Model, subject::U, observer::ObserverDNA{V})::U where {V<:SubjectDNA, U<:V}
    put!(self._builder, (subject, observer))
    return subject
end

"""
Schedule the subgraph of a Dependent to be evaluated.
- All nodes reachable from this one will be evaluated.
"""
function Base.schedule(self::Model, d::DependentDNA)
    schedule(self._scheduler, d)
end

"""
Decide at the beginning of the frame, which state the model is in.
- update! of the model is also state dependent.
- This state is carried until the end of endState call.
"""
function decideState(self::Model)::ModelState
    if !isFinished(self._scheduler)
        @assert islocked_by_model(self._builder) "Lock lost by Model in EvalingState!"
        
        # ? I still have the lock from ViewingState or EvalingState.
        
        return EvalingState()
    elseif islocked_by_model(self._builder)
        
        # ? Scheduler was unifinished at end of frame, but finished at decideState.
        # ? Should unlock Builder.

        unlock_by_model(self._builder)
    end
    
    if !isempty(self._adder) 
        @assert !islocked_by_model(self._builder) "Builder can't be locked by Model in BuildingState!"

        # ? Adder still has elements, should handle thoose. 
        
        return BuildingState()
    end
    
    # ? Should fight for the lock.
    if trylock_by_model(self._builder)
        @assert islocked_by_model(self._builder) "Model didn't get Builder's Lock!"
        
        # ? Model got Lock from Builder.
        # ? Unlock Builder at the end of the frame.
        
        return ViewingState()
    else
        @assert !islocked_by_model(self._builder) "Lock must be owned by Builder!"
        
        # ? Failed locking, Builder must be building.
        
        return BuildingState()
    end
end

"""
Get a reference to the Dependent with the given graphID.
- Query time is just indexing into a list, so fast.
"""
function getDependentNode(self::Model, graphID::Int)::DependentDNA
    return _getDependentNode(self._graph, graphID)
end


# ? BuildingState

function update!(self::Model, ::BuildingState)::Bool
    return processAvailable!(self._adder)
end

function endState(self::Model, state::BuildingState)
    return nothing
end

# ? ViewingState

function update!(self::Model, ::ViewingState)::Bool
    scene_change = false
    if !isempty(self._scheduler)
        scene_change = true
        mode = self._scheduler._mode

        if (mode isa SingleFrameSingleThread)
            @time_cpu_begin Graph_update
            # ? Scheduler will schedule work only to Worker0.
            startGraphWorkers!(self._scheduler, self)
            # ? Modell task shall complete Worker0.
            processUntilClosed!(getWorkers(self)[0], self)
            # ? Worker0 forwards work to Internal Queue.
            processInternal!(self._synchronizer)
            @time_cpu_end Graph_update
            
            block = @get_block Graph_update
            # TODO: Save and Display theese times for benchmarks.
            ccputime = _cputime(block)

        elseif (mode isa SingleFrameTwoThreads)
            @time_cpu_begin Graph_update
            # ? Scheduler will schedule work only to Worker1.
            startGraphWorkers!(self._scheduler, self)
            # ? Must process Root nodes.
            processInternal!(self._synchronizer)
            # ? Modell Task must process all Subject and wait for all work to be completed.
            processUntilFinishedExternal!(self._synchronizer, self)
            @time_cpu_end Graph_update
            
            block = @get_block Graph_update
            # TODO: Save and Display theese times for benchmarks.
            ccputime = _cputime(block)

        elseif (mode isa SingleFrameMultipleThreads)
            @time_cpu_begin Graph_update
            # ? Scheduler will schedule work to all Workeri.
            startGraphWorkers!(self._scheduler, self)
            # ? Must process Root nodes.
            processInternal!(self._synchronizer)
            # ? Modell Task must process all Subject and wait for all work to be completed.
            processUntilFinishedExternal!(self._synchronizer, self)
            @time_cpu_end Graph_update
            
            block = @get_block Graph_update
            # TODO: Save and Display theese times for benchmarks.
            ccputime = _cputime(block)

        elseif (mode isa MultipleFramesSingleThread)
            @time_cpu_begin Graph_update
            # ? Scheduler will schedule work to all Workeri.
            startGraphWorkers!(self._scheduler, self)
            # ? Must process Root nodes.
            processInternal!(self._synchronizer)
            # ? Process only available observers.
            processAvailableExternal!(self._synchronizer, self)
            # ? Let Model step into next state, BuildingState.
        elseif (mode isa MultipleFramesMultipleThreads)
            @time_cpu_begin Graph_update
            # ? Scheduler will schedule work to all Workeri.
            startGraphWorkers!(self._scheduler, self)
            # ? Must process Root nodes.
            processInternal!(self._synchronizer)
            # ? Process only available observers.
            processAvailableExternal!(self._synchronizer, self)
            # ? Let Model step into next state, BuildingState.
        end
    end
    return scene_change
end

function endState(self::Model, state::ViewingState)
    if isFinished(self._scheduler)
        if isFinishedFirst(self._scheduler)
            isCorrect = isFinishedCorrectly!(self._scheduler)
            @assert isCorrect "Evaling didn't finish correctly!"
            
            if self._scheduler._mode isa Union{MultipleFramesSingleThread, MultipleFramesMultipleThreads}
                @time_cpu_end Graph_update
                
                block = @get_block Graph_update
                # TODO: Save and Display theese times for benchmarks.
                ccputime = _cputime(block)
            end
        end

        # ? Let Builder process Dependents.
        unlock_by_model(self._builder)
    end
end

# ? EvalingState

function update!(self::Model, ::EvalingState)::Bool
    # ? Internal was processed in ViewingState, which started EvalingState.
    return processAvailableExternal!(self._synchronizer, self)
end

function endState(self::Model, state::EvalingState)
    if isFinished(self._scheduler)
        if isFinishedFirst(self._scheduler)
            isCorrect = isFinishedCorrectly!(self._scheduler)
            @assert isCorrect "Evaling didn't finish correctly!" 
            
            if self._scheduler._mode isa Union{MultipleFramesSingleThread, MultipleFramesMultipleThreads}
                @time_cpu_end Graph_update
                
                block = @get_block Graph_update
                # TODO: Save and Display theese times for benchmarks.
                ccputime = _cputime(block)
            end
        end

        # ? Let Builder process Dependents.
        unlock_by_model(self._builder)
    end
end