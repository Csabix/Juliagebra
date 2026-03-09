
const DEFAULT_CALLBACK_FUNC() = return nothing
const DEFAULT_DEPENDENTS = Vector{DependentDNA}()

global implicitApp::Union{AppDNA,Nothing} = nothing
global greenTask::Union{Any,Nothing} = nothing

abstract type FrameState end
struct BuildingState <: FrameState end
struct ViewingState <: FrameState end

const ADDED_CHANNEL_SIZE = 64
const ADDED_PER_FRAME_MAX = 64

struct BuildData
    dependent::Union{DependentDNA,Nothing}
    observer::Union{ObserverDNA,Nothing}
    pool::Union{ObserverPool,Nothing}
end

# ? ---------------------------------
# ! Synchronizer
# ? ---------------------------------

mutable struct Synchronizer
    _lock::ReentrantLock
    _channel::Channel{BuildData}
    _initLock::ReentrantLock
    _initCondition::Threads.Condition

    function Synchronizer()
        lock = ReentrantLock()
        # ? ADDED_CHANNEL_SIZE elements max on the BLUE Thread, otherwise wait
        channel = Channel{BuildData}(ADDED_CHANNEL_SIZE)
        initLock = ReentrantLock()
        initCondition = Threads.Condition(initLock)
        new(lock,channel,initLock,initCondition)
    end
end

# GREEN Thread
function decideFrameState(app::AppDNA)::FrameState
    s::Synchronizer = getSynchronizer(app)

    if trylock(s._lock)
        # ? locked succesfully, no one can start constructing this frame,
        # ? unlock this lock at the end of the frame.
        return ViewingState()
    else
        # ? failed locking, must have started building...
        return BuildingState()
    end
end

# Green Thread
function handleAddedCalls(app::AppDNA)
    s::Synchronizer = getSynchronizer(app)
    builtDependentsNum = Base.n_avail(s._channel)
    # ? at max process ADDED_PER_FRAME_MAX dependents in this frame.
    takeNum = min(builtDependentsNum,ADDED_PER_FRAME_MAX)
    addedAllSet = Set{Tuple{ObserverDNA,ObserverPool}}()
    
    for i in 1:takeNum

        data::BuildData = take!(s._channel)
        dependent = data.dependent
        observer = data.observer
        pool = data.pool
        
        _handleAddedCalls1(dependent,app)

        if !isnothing(observer)
            push!(addedAllSet,(observer,pool))
        end
    end
    
    for (observer,pool) in addedAllSet
        # TODO: Continue this.
        addedAll!(pool,observer)
        # activate!(pool,Type2Id(typeof(observer)))
    end

    if takeNum > 1
        @log "Built $(takeNum)!"
    end
end

# Green Thread
function _handleAddedCalls1(::DependentDNA,::AppDNA)
    # ? The BLUE Thread already did the required building work.
    return nothing
end

# Green Thread
function _handleAddedCalls1(rendered::RenderedDependentDNA,app::AppDNA)
    renderer::ObserverDNA = getObserver(rendered)
    added!(renderer,rendered)
    setRenderedID!(renderer,rendered,getGraphID(rendered) + ID_LOWER_BOUND)
end

# Green Thread
function _handleAddedCalls1(rendered::GuiDependentDNA,::AppDNA)
    renderer::ObserverDNA = getObserver(rendered)
    added!(renderer,rendered)
end

# GREEN THREAD
function startOpengl()
    global implicitApp
    println("OpenGL: $(Threads.threadid())")
    play!(implicitApp)
end

# YELLOW Thread
function Wait()
    global greenTask
    
    wait(greenTask)
    println("Main Thread ended!")
end

# YELLOW Thread
"""
The lambda must only construct a single Dependent, and return it.
"""
function build!(lambda::Function)::DependentDNA    
    global implicitApp
    global greenTask
    
    if isnothing(implicitApp)
        implicitApp = App()
        
        greenTask = ThreadPinning.@spawnat 1 begin
            startOpengl()
        end
        errormonitor(greenTask)
        
        s::Synchronizer = getSynchronizer(implicitApp)
        lock(s._initCondition)
        wait(s._initCondition)
        unlock(s._initCondition)
    end

    # ? Start constructing on the Blue Thread
    blueTask = Threads.@spawn begin
        return _build1(lambda,implicitApp)
    end
    errormonitor(blueTask)

    return fetch(blueTask)
end

# BLUE Thread
function _build1(lambda::Function,app::AppDNA)
    s::Synchronizer = getSynchronizer(app)
    local dependent::DependentDNA

    lock(s._lock) do 
        dependent = lambda()
        observer, pool = _build2(app,dependent)
        data = BuildData(dependent,observer,pool)
        put!(s._channel,data)
    end

    return dependent
end

# BLUE Thread
function _build2(app::AppDNA,dependent::DependentDNA)
    # TODO: Continue this.
    graph = getGraph(app)
    add!!(graph,dependent)

    onNodeEval(dependent)

    return (nothing,nothing)
end

# BLUE Thread
function _build2(app::AppDNA, rendered::RenderedDependentDNA)
    # TODO: Continue this.
    graph = getGraph(app)
    renderer = Dependent2Observer(app,rendered)

    add!!(renderer,rendered)
    add!!(graph,rendered)

    onNodeEval(rendered)

    return (renderer,nothing)
end

# BLUE Thread
function _build2(app::AppDNA, rendered::GuiDependentDNA)
    # TODO: Continue this.
    graph = getGraph(app)
    renderer = getRendererFor(app,rendered)
    pool = getPoolFor(app,renderer)

    add!!(renderer,rendered)
    add!!(graph,rendered)

    onNodeEval(rendered)

    return (renderer,pool)
end

getRendererFor(app::AppDNA,d::GuiDependentDNA) = return getImGui(app)._dock._windows[1]._pool[Type2Id(Dependent2ObserverT(d)),Val(:all)]
getPoolFor(app::AppDNA,::GuiRendererDNA) = return getImGui(app)._dock._windows[1]._pool

destroy!(self::Synchronizer) = close(self._channel)