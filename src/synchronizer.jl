
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
    _initLock::ReentrantLock
    _initCondition::Threads.Condition
    
    # ? Commands
    _external::Channel{Command}
    _internal::Queue{Command}

    function Synchronizer()
        initLock = ReentrantLock()
        initCondition = Threads.Condition(initLock)
        
        external = Channel{Command}(1)
        internal = Queue{Command}()

        new(initLock,initCondition,external,internal)
    end
end

# Green Thread
function destroy!(self::Synchronizer) 
    close(self._external)
end

# GREEN Thread
function decideFrameState(app::AppDNA)::FrameState
    s::Synchronizer = getSynchronizer(app)
    b::Builder = getBuilder(app)
    a::Adder = getAdder(app)

    if !isempty(a)
        # ? Adder has elements, should handle thoose.
        return BuildingState()
    elseif trylock(b)
        # ? locked succesfully, Builder is stopped for this frame,
        # ? unlock Builder at the end of the frame.
        return ViewingState()
    else
        # ? failed locking, Builder must be building.
        return BuildingState()
    end
end

# Green Thread
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

# YELLOW Thread
function Empty()
    global implicitApp
    
    if !isnothing(implicitApp)
        s::Synchronizer = getSynchronizer(implicitApp)
        put!(s._external,EmptySceneCommand())
    end
end

# GREEN THREAD
function startOpengl()
    global implicitApp
    println("OpenGL: $(Threads.threadid())")
    play!(implicitApp)
    implicitApp = nothing
end

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

# GREEN Thread (in script)
"""
Send a newly constructed Dependent to the build system of an app.
- By default, implicitApp is used.
- If app reference is nothing, implicitApp is inited.
"""
function build!(dependent::DependentDNA, app::Union{AppDNA,Nothing}=implicitApp)::DependentDNA    
    global implicitApp
    global greenTask
    
    if isnothing(app)
        implicitApp = App()
        
        greenTask = ThreadPinning.@spawnat 1 begin
            startOpengl()
        end
        errormonitor(greenTask)
        
        s = getSynchronizer(implicitApp)
        lock(s._initCondition)
        wait(s._initCondition)
        unlock(s._initCondition)

        app = implicitApp
    end

    put!(getBuilder(app),dependent)
    #yield()

    return dependent
end