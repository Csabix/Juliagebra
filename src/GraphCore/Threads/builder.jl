
# ? ---------------------------------
# ! Builder
# ? ---------------------------------

const BUILDER_IN_CHANNEL_SIZE = 100

"""
Builds un-built Dependents up until added! and addedAll!! calls.
"""
@kwdef mutable struct Builder
    _in::Channel{DependentDNA} = Channel{DependentDNA}(BUILDER_IN_CHANNEL_SIZE)
    _lock::ReentrantLock = ReentrantLock()
end

destroy!(self::Builder) = close(self._in)
Base.put!(self::Builder,d::DependentDNA) = put!(self._in,d)
Base.lock(self::Builder) = lock(self._lock)
Base.lock(f::Function, self::Builder) = lock(f,self._lock)
Base.unlock(self::Builder) = unlock(self._lock)
Base.trylock(self::Builder) = trylock(self._lock)

# YELLOW Thread
function processUntilClosed!(self::Builder, app::AppDNA)
    a::Adder = getModel(app)._adder

    for dependent in self._in
        # ? App must be in BuildingState.
        lock(self) do 
            @invokelatest _build(app,dependent)
            # ? Forward the Dependent to the Adder.
            put!(a,dependent)
        end
    end

    println("ThreadID($(Threads.threadid())): Builder Ended!")
end

# YELLOW Thread
function _build(app::AppDNA, dependent::DependentDNA)
    @assert isUnbuilt(dependent) "Dependent is already built!"
    
    graph = getModel(app)._graph
    
    add!!(graph,dependent)

    setEntryNodes(dependent)
    onNodeEval(dependent)
end

# YELLOW Thread
function _build(app::AppDNA, observed::ObservedDNA)
    @assert isUnbuilt(observed) "Observed is already built!"
    
    graph = getModel(app)._graph
    observer = Dependent2Observer(app,observed)
    
    add!!(observer,observed)
    add!!(graph,observed)

    setEntryNodes(observed)
    onNodeEval(observed)
end