
# ? ---------------------------------
# ! Builder
# ? ---------------------------------

const BUILDER_IN_CHANNEL_SIZE = 8192
const _BuilderT = Union{DependentDNA,Tuple{ObservedDNA,ObserverDNA}}

global _builderTimes = Vector{Float64}()

"""
Builds un-built Dependents up until added! and addedAll!! calls.
"""
@kwdef mutable struct Builder
    _in::Channel{_BuilderT} = Channel{_BuilderT}(BUILDER_IN_CHANNEL_SIZE)
    _lock::ReentrantLock = ReentrantLock()
end

destroy!(self::Builder) = close(self._in)
Base.put!(self::Builder,node::_BuilderT) = put!(self._in,node)
Base.lock(self::Builder) = lock(self._lock)
Base.lock(f::Function, self::Builder) = lock(f,self._lock)
Base.unlock(self::Builder) = unlock(self._lock)
Base.trylock(self::Builder) = trylock(self._lock)

# YELLOW Thread
function processUntilClosed!(self::Builder, model::ModelDNA)
    for node in self._in
        # ? Must wait for Model to be in BuildingState.
        lock(self) do 
            @invokelatest _build(model,node)
        end
    end

    #global BUILDER_PATH
    #open(BUILDER_PATH, "a") do io
    #    println(io, join(_builderTimes,","))        
    #end

    println("ThreadID($(Threads.threadid())): Builder Ended!")
end

# YELLOW Thread
function _build(model::ModelDNA, dependent::DependentDNA)
    @assert isUnbuilt(dependent) "Dependent is already built!"
    
    graph::DependentGraph = getGraph(model)

    startTime = time_ns()
    add!!(graph,dependent)
    endTime = time_ns()
    push!(_builderTimes,(endTime-startTime)/1000000.0)

    setEntryNodes(dependent)
    onNodeEval(dependent)
end

# YELLOW Thread
function _build(model::ModelDNA, oo::Tuple{ObservedDNA,ObserverDNA})
    observed::ObservedDNA = oo[1]
    observer::ObserverDNA = oo[2]
    
    @assert isUnbuilt(observed) "Observed is already built!"
    
    graph::DependentGraph = getGraph(model)
    adder::Adder = getAdder(model)

    add!!(observer,observed)
    
    startTime = time_ns()
    add!!(graph,observed)
    endTime = time_ns()
    push!(_builderTimes,(endTime-startTime)/1000000.0)

    setEntryNodes(observed)
    onNodeEval(observed)

    # ? Forward the Observed to the Adder.
    put!(adder,observed)
end