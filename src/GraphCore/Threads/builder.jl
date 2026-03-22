
# ? ---------------------------------
# ! Builder
# ? ---------------------------------

"""
Builds just constructed Dependents up until added! and addedAll!! calls.
"""
@kwdef mutable struct Builder
    _in::Channel{DependentDNA} = Channel{DependentDNA}(100)
end

function destroy!(self::Builder)
    close(self._in)
end

function send!(self::Builder,d::DependentDNA)
    put!(self._in,d)
end

# YELLOW Thread
function doWork(self::Builder,app::AppDNA)
    s::Synchronizer = getSynchronizer(app)
    
    for dependent in self._in
        # ? App must be in BuildingState.
        lock(s._lock) do 
            @invokelatest _build(app,dependent)
            # ? Forward the Dependent to the app.
            put!(s._channel,dependent)
        end
    end

    println("ThreadID($(Threads.threadid())): Builder Ended!")
end

# YELLOW Thread
function _build(app::AppDNA,dependent::DependentDNA)
    @assert isUnbuilt(dependent) "Dependent is already built!"
    
    graph = getGraph(app)
    
    add!!(graph,dependent)

    setEntryNodes(dependent)
    onNodeEval(dependent)
end

# YELLOW Thread
function _build(app::AppDNA, observed::ObservedDNA)
    @assert isUnbuilt(observed) "Observed is already built!"
    
    graph = getGraph(app)
    observer = Dependent2Observer(app,observed)
    
    add!!(observer,observed)
    add!!(graph,observed)

    setEntryNodes(observed)
    onNodeEval(observed)
end