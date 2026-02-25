
const DEFAULT_CALLBACK_FUNC() = return nothing
const DEFAULT_DEPENDENTS = Vector{DependentDNA}()

# ? ---------------------------------
# ! Synchronizer
# ? ---------------------------------

mutable struct Synchronizer
    _lock::ReentrantLock
    _channel::Channel{DependentDNA}

    function Synchronizer()
        lock = ReentrantLock()
        channel = Channel{DependentDNA}(32) # ? 32 elements max, otherwise wait
        new(lock,channel)
    end
end

# GREEN Thread
function updateState(app::AppDNA)
    s::Builder = getSynchronizer(app)

    if trylock(s._lock)
        # ? locked succesfully, no one can start constructing this frame,
        # ? unlock this lock at the end of the frame.
    else
        # ? someone is building...
    end
end

# YELLOW Thread
function build!(lambda::Function,app::AppDNA = implicitApp)::DependentDNA
    
    # ? Start constructing on the Blue Thread
    blueTask = ThreadPinning.@spawnat 2 begin
        return _build1(lambda,app)
    end

    return Base.fetch(blueTask)
end

# BLUE Thread
function _build1(lambda::Function,app::AppDNA)
    s::Synchronizer = getSynchronizer(app)
    local dependent::DependentDNA
        
    lock(s._lock) do 
        dependent = lambda()
        _build(app,dependent)
        put!(s._channel,dependent)
    end

    return dependent
end

# BLUE Thread
function _build2(app::AppDNA,dependent::DependentDNA)
    graph = getGraph(app)
    add!!(graph,dependent)

    onNodeEval(dependent)
end

# BLUE Thread
function _build2(app::AppDNA,observed::ObservedDNA)
    graph = getGraph(app)
    observer = getObserverFrom(app,observed)

    add!!(observer,observed)
    add!!(graph,observed)

    onNodeEval(observed)
end

# BLUE Thread
function _build2(app::AppDNA, rendered::RenderedDependentDNA)
    graph = getGraph(app)
    renderer = getObserverFrom(app,rendered)

    add!!(renderer,rendered)
    add!!(graph,rendered)
    #setRenderedID!(renderer,rendered,getGraphID(rendered) + ID_LOWER_BOUND)

    onNodeEval(rendered)
end

getObserverFrom(app::AppDNA,rendered::RenderedDependentDNA) = return Plan2Observer(getOpenGL(app),rendered)
getObserverFrom(app::AppDNA,rendered::GuiDependentDNA) = return Plan2Observer(getImGui(app),rendered)
