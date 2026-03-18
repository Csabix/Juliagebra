
const DEFAULT_CALLBACK_FUNC() = return nothing
const DEFAULT_DEPENDENTS = Vector{DependentDNA}()

# implicitApp and greenTask are forward-declared in Juliagebra.jl

abstract type FrameState end
struct BuildingState <: FrameState end
struct ViewingState <: FrameState end

abstract type Command end
struct EmptySceneCommand <: Command end


const ADDED_CHANNEL_SIZE = 64
const ADDED_PER_FRAME_MAX = 64
const ADDED_MIN_MS = 0.001

# ? ---------------------------------
# ! Synchronizer
# ? ---------------------------------

mutable struct Synchronizer
    # ? Building state.
    _lock::ReentrantLock
    _channel::Channel{DependentDNA}
    _initLock::ReentrantLock
    _initCondition::Threads.Condition
    
    # ? Commands
    _external::Channel{Command}
    _internal::Queue{Command}

    function Synchronizer()
        lock = ReentrantLock()
        # ? ADDED_CHANNEL_SIZE elements max on the BLUE Thread, otherwise wait
        channel = Channel{DependentDNA}(ADDED_CHANNEL_SIZE)
        initLock = ReentrantLock()
        initCondition = Threads.Condition(initLock)
        
        external = Channel{Command}(1)
        internal = Queue{Command}()

        new(lock,channel,initLock,initCondition,external,internal)
    end
end

function destroy!(self::Synchronizer) 
    close(self._channel)
    close(self._external)
end

# GREEN Thread
function decideFrameState(app::AppDNA)::FrameState
    s::Synchronizer = getSynchronizer(app)

    if !isempty(s._channel)
        return BuildingState()
    elseif trylock(s._lock)
        # ? locked succesfully, no one can start constructing this frame,
        # ? unlock this lock at the end of the frame.
        return ViewingState()
    else
        # ? failed locking, must have started building...
        return BuildingState()
    end
end

function handleCommands!(app::AppDNA)
    s::Synchronizer = getSynchronizer(app)
    c::Union{Command,Nothing} = nothing
    
    if !isempty(s._internal)
        c = popfirst!(s._internal)
    elseif !isempty(s._external)
        c = take!(s._external)
    end
    
    if c isa EmptySceneCommand
        o::OpenGLData = getOpenGL(app)
        i::ImGuiData = getImGui(app)
        g::DependentGraph = getGraph(app)
        
        empty!(g)
        resetObservers!(o)
        resetObservers!(i)
    end
end

function Empty()
    global implicitApp
    
    if !isnothing(implicitApp)
        s::Synchronizer = getSynchronizer(implicitApp)
        put!(s._external,EmptySceneCommand())
    end
end

# Green Thread
function handleAddedCalls(app::AppDNA)
    s::Synchronizer = getSynchronizer(app)
    builtDependentsNum = Base.n_avail(s._channel)
    
    # ? at max process ADDED_PER_FRAME_MAX dependents in this frame.
    takeNum = min(builtDependentsNum,ADDED_PER_FRAME_MAX)
    startTime = time()
    addedAllSet = Set{ObserverDNA}()
    
    for i in 1:takeNum

        dependent = take!(s._channel)
        observer = _handleAddedCalls(app,dependent)

        if !isnothing(observer)
            # ? An Observer was assigned to this dependent.
            push!(addedAllSet,observer)
        end

        if (time() - startTime)>(ADDED_MIN_MS/2.0)
            takeNum = i
            break
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
    implicitApp = nothing
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
    yield()

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