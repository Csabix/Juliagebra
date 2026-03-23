
# ? ---------------------------------
# ! Commander
# ? ---------------------------------

@kwdef mutable struct Commander
    _external::Channel{Command} = Channel{Command}(1)
    _internal::Queue{Command} = Queue{Command}()
end

destroy!(self::Commander) = close(self._external)
"""
Non-blocking, thread unsafe way to put Commands into Commander.
"""
putInternal!(self::Commander, c::Command) = push!(self._internal,c)
"""
Blocking, Threadsafe way to put Commands into Commander.
"""
putExternal!(self::Commander, c::Command) = put!(self._external,c)

# Green Thread
function handleCommands!(app::AppDNA)
    s::Commander = getCommander(app)
    c::Union{Command,Nothing} = nothing
    
    if !isempty(s._internal)
        c = popfirst!(s._internal)
    elseif !isempty(s._external)
        c = take!(s._external)
    end
    
    if !isnothing(c)
        handleCommand!(app,c)
    end
end

function handleCommand!(app::AppDNA, command::Command) 
    error("Missing func!")
end

function handleCommand!(app::AppDNA, ::EmptySceneCommand)
    o::OpenGLData = getOpenGL(app)
    i::ImGuiData = getImGui(app)
    g::DependentGraph = getGraph(app)
    
    empty!(g)
    resetObservers!(o)
    resetObservers!(i)
end

# GREEN Thread
function decideFrameState(app::AppDNA)::FrameState
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

# YELLOW Thread
function Empty()
    global implicitApp
    
    if !isnothing(implicitApp)
        putExternal!(getCommander(implicitApp),EmptySceneCommand())
    end
end

function Wait()
    global greenTask
    wait(greenTask)
    println("ThreadID($(Threads.threadid())): Main Thread Ended!")
end

function Window(callback::Function)
    @warn "Window() command is depreciated!"
    callback()
    Wait()
end

