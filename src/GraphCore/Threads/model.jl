
abstract type ModelState end
struct BuildingState <: ModelState end
struct ViewingState <: ModelState end
struct EvalingState <: ModelState end

# ? ---------------------------------
# ! Model
# ? ---------------------------------

@kwdef mutable struct Model <: ModelDNA
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

function init!(self::Model)
    # YELLOW Thread start
    builderTask = Threads.@spawn begin
        processUntilClosed!(self._builder,self)
    end
    errormonitor(builderTask)

    self._builderTask = builderTask

    for i in 1:length(self._workers)
        # RED Thread start
        workerTask = Threads.@spawn begin
            processUntilClosed!(self._workers[i], self)
        end
        errormonitor(workerTask)

        push!(self._workerTasks, workerTask)
    end
end

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
"""
function build!(self::Model, dependent::T)::T where {T<:DependentDNA}
    put!(self._builder, dependent)
    return dependent
end

"""
Send a newly constructed Observed to the build system of a Model.
- An Observer for this Observed is required.
"""
function build!(self::Model, observed::U, observer::ObserverDNA{V})::U where {V<:ObservedDNA, U<:V}
    put!(self._builder, (observed, observer))
    return observed
end

"""
Schedule the subgraph of a Dependent to be evaluated.
"""
function Base.schedule(self::Model, d::DependentDNA)
    schedule(self._scheduler, d)
end

"""
Decide at the beginning of the frame, which state the model is in.
- Call beginState after it.
- update! of the model is also state dependent.
- This state is carried until the end of endState.
"""
function decideState(self::Model)::ModelState
    if !isFinished(self._scheduler)
        # ? I still have the lock from ViewingState.
        return EvalingState()
    elseif !isempty(self._adder)
        # ? Adder still has elements, should handle thoose.
        return BuildingState()
    elseif trylock(self._builder)
        # ? locked succesfully, Builder is stopped for this frame,
        # ? unlock Builder at the end of the frame.
        return ViewingState()
    else
        # ? failed locking, Builder must be building.
        return BuildingState()
    end
end



# ? BuildingState

function beginState(self::Model, state::BuildingState)
    return nothing
end

function update!(self::Model, ::BuildingState)
    processAvailable!(self._adder)
end

function endState(self::Model, state::BuildingState)
    return nothing
end




# ? ViewingState

function beginState(self::Model, state::ViewingState)
    return nothing
end

function update!(self::Model, ::ViewingState)
    
    if !isempty(self._scheduler)
        mode = self._scheduler._mode

        if (mode isa SingleFrameSingleThread)
            @time_cpu_begin Graph_update
            startGraphWorkers!(self._scheduler, self)
            processUntilClosed!(getWorkers(self)[0], self)
            processInternal!(self._synchronizer)
            @time_cpu_end Graph_update
        
        elseif (mode isa MultipleFramesSingleThread)
            startGraphWorkers!(self._scheduler, self)
            processInternal!(self._synchronizer)
            processAvailableExternal!(self._synchronizer, self)
            # ? Let Model step into next state, BuildingState.
        elseif (mode isa MultipleFramesMultipleThreads)
            startGraphWorkers!(self._scheduler, self)
            processInternal!(self._synchronizer)
            processAvailableExternal!(self._synchronizer, self)
            # ? Let Model step into next state, BuildingState.
        end
    end
end

function endState(self::Model, state::ViewingState)
    if isFinished(self._scheduler)
        @assert isFinishedCorrectly(self._scheduler) "Evaling didn't finish correctly!"
        # ? Let Builder process Dependents. Next state for sure will be ViewingState.
        unlock(self._builder)
    end
end

# ? EvalingState

function beginState(self::Model, state::EvalingState)
    return nothing
end

function update!(self::Model, ::EvalingState)
    # ? Internal was processed in ViewingState, which started EvalingState.
    processAvailableExternal!(self._synchronizer, self)
end

function endState(self::Model, state::EvalingState)
    if isFinished(self._scheduler)
        @assert isFinishedCorrectly(self._scheduler) "Evaling didn't finish correctly!"
        # ? Let Builder process Dependents. Next state for sure will be ViewingState.
        unlock(self._builder)
    end
end