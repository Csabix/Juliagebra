
abstract type ModelState end
struct BuildingState <: ModelState end
struct ViewingState <: ModelState end

# ? ---------------------------------
# ! Model
# ? ---------------------------------

@kwdef mutable struct Model <: ModelDNA
    _graph::DependentGraph = DependentGraph()
    _adder::Adder = Adder()
    _builder::Builder = Builder()
    _scheduler::Scheduler = Scheduler()
    _worker::GraphWorker = GraphWorker()
    _synchronizer::Synchronizer = Synchronizer()
end

getGraph(self::Model)::DependentGraph = self._graph
getAdder(self::Model)::Adder = self._adder
getBuilder(self::Model)::Builder = self._builder
getScheduler(self::Model)::Scheduler = self._scheduler
getWorker(self::Model)::GraphWorker = self._worker
getSynchronizer(self::Model)::Synchronizer = self._synchronizer

function destroy!(self::Model)
    destroy!(self._adder)
    destroy!(self._builder)
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
    if !isempty(self._adder)
        # ? Adder has elements, should handle thoose.
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

end

function update!(self::Model, ::BuildingState)
    processBatch!(self._adder)
end

function endState(self::Model, state::BuildingState)

end




# ? ViewingState

function beginState(self::Model, state::ViewingState)

end

function schedule!(self::Model, d::DependentDNA)

end

function update!(self::Model, ::ViewingState)
    if !isempty(self._scheduler)
        @time_cpu_begin Graph_update
        startGraphWorkers!(self._scheduler, self)
        processUntilClosed!(self._worker, self)
        processBatch!(self._synchronizer)
        @time_cpu_end Graph_update
    end
end

function endState(self::Model, state::ViewingState)
    # ? Let Builder process Dependents.
    unlock(self._builder)
end