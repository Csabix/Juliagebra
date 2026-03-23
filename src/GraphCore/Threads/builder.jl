
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
    a::Adder = getAdder(app)

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

# GREEN Thread (in script)
"""
Send a newly constructed Dependent to the build system of implicitApp.
- If implicitApp is nothing, it is initialized, and started.
- The App will run on greenTask.
"""
function build!(dependent::T)::T where {T<:DependentDNA}
    global implicitApp
    global greenTask

    if isnothing(implicitApp)
        implicitApp = App()
        greenTask = startApp(implicitApp)
    end

    build!(dependent,implicitApp)
    return dependent
end

# GREEN Thread (in script)
"""
Send a newly constructed Dependent to the build system of app.
- App must be started.
"""
function build!(dependent::T, app::AppDNA)::T where {T<:DependentDNA}
    @assert isStarted(getStarter(app)) "App is not started properly!"

    put!(getBuilder(app),dependent)
    return dependent
end