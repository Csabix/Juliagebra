
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

        dependent = take!(s._channel)
        observer = _handleAddedCalls(app,dependent)

        if !isnothing(observer)
            # ? An Observer was assigned to this dependent.
            push!(addedAllSet,observer)
        end
    end
    
    for observer in addedAllSet        
        # ? Must call addedAll! and activate!
        addedAll!(observer)
    end

    if takeNum > 1
        @log "Built $(takeNum)!"
    end
end

# Green Thread
function _handleAddedCalls(::AppDNA,::DependentDNA)
    # ? The BLUE Thread already did the required building work.
    return nothing
end

# Green Thread
function _handleAddedCalls(::AppDNA,observed::ObservedDNA)
    observer = getObserver(observed)
    added!(observer,observed)
    _setHasInstance!(observer)
    return observer
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

function Window(callback::Function)
    yellowTask = Threads.@spawn begin
        callback()
    end
    
    wait(yellowTask)
    Wait()
end

# YELLOW Thread
"""
The lambda must only construct a single Dependent, and return it.
"""
function build!(dependent::DependentDNA)::DependentDNA    
    global implicitApp
    global greenTask
    
    local s::Synchronizer
    
    if isnothing(implicitApp)
        implicitApp = App()
        
        greenTask = ThreadPinning.@spawnat 1 begin
            startOpengl()
        end
        errormonitor(greenTask)
        
        s = getSynchronizer(implicitApp)
        lock(s._initCondition)
        wait(s._initCondition)
        unlock(s._initCondition)
    end

    s = getSynchronizer(implicitApp)
    
    lock(s._lock) do 
        _build(implicitApp,dependent)
        put!(s._channel,dependent)
    end

    return dependent
end

# YELLOW Thread
function _build(app::AppDNA,dependent::DependentDNA)
    graph = getGraph(app)
    
    add!!(graph,dependent)

    onNodeEval(dependent)
end

# YELLOW Thread
function _build(app::AppDNA, observed::ObservedDNA)
    graph = getGraph(app)
    observer = Dependent2Observer(app,observed)
    
    add!!(observer,observed)
    add!!(graph,observed)

    onNodeEval(observed)
end

destroy!(self::Synchronizer) = close(self._channel)