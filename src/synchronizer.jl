
const DEFAULT_CALLBACK_FUNC() = return nothing
const DEFAULT_DEPENDENTS = Vector{DependentDNA}()

global implicitApp::Union{AppDNA,Nothing} = nothing
global greenTask::Union{Any,Nothing} = nothing

abstract type FrameState end
struct BuildingState <: FrameState end
struct ViewingState <: FrameState end

const ADDED_CHANNEL_SIZE = 64
const ADDED_PER_FRAME_MAX = 64

# ? ---------------------------------
# ! Synchronizer
# ? ---------------------------------

mutable struct Synchronizer
    _lock::ReentrantLock
    _channel::Channel{DependentDNA}
    _initLock::ReentrantLock
    _initCondition::Threads.Condition

    function Synchronizer()
        lock = ReentrantLock()
        # ? ADDED_CHANNEL_SIZE elements max on the BLUE Thread, otherwise wait
        channel = Channel{DependentDNA}(ADDED_CHANNEL_SIZE)
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
    addedAllSet = Set{ObserverDNA}()
    
    for i in 1:takeNum

        dependent::DependentDNA = take!(s._channel)
        observer = _handleAddedCalls1(dependent,app)

        if !isnothing(observer)
            push!(addedAllSet,observer)
        end
    end
    
    for observer in addedAllSet
        addedAll!(app,observer)
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

    return renderer
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
    
    return fetch(blueTask)
end

# BLUE Thread
function _build1(lambda::Function,app::AppDNA)
    s::Synchronizer = getSynchronizer(app)
    local dependent::DependentDNA

    lock(s._lock) do 
        dependent = lambda()
        _build2(app,dependent)
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
#function _build2(app::AppDNA,observed::ObservedDNA)
#    graph = getGraph(app)
#    observer = Dependent2Observer(app,observed)
#
#    add!!(observer,observed)
#    add!!(graph,observed)
#
#    onNodeEval(observed)
#end

# BLUE Thread
function _build2(app::AppDNA, rendered::RenderedDependentDNA)
    graph = getGraph(app)
    renderer = Dependent2Observer(app,rendered)

    add!!(renderer,rendered)
    add!!(graph,rendered)
    #setRenderedID!(renderer,rendered,getGraphID(rendered) + ID_LOWER_BOUND)

    onNodeEval(rendered)
end


getObserverFor(app::AppDNA,rendered::GuiDependentDNA) = return Plan2Observer(getImGui(app),rendered)
destroy!(self::Synchronizer) = close(self._channel)