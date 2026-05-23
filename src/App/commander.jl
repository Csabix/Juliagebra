
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
    m::Model = getModel(app)
    g::DependentGraph = m._graph
    
    sceneChanged(app)
    empty!(g)
    resetObservers!(o)
    resetObservers!(i)
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
    
    if isnothing(greenTask)
        @warn "Can't wait on empty scnene!"
        return
    end
    
    wait(greenTask)
    println("ThreadID($(Threads.threadid())): Main Thread Ended!")
end

function Window(callback::Function)
    @warn "Window() command is depreciated!"
    callback()
    Wait()
end

# GREEN Thread (in script)
"""
Send a newly constructed Dependent to the build system of implicitApp.
- If implicitApp is nothing, it is initialized, and started.
- The App will run on greenTask.
"""
function Build!(dependent::T)::T where {T<:DependentDNA}
    global implicitApp
    global greenTask

    if isnothing(implicitApp)
        implicitApp = App()
        greenTask = startApp(implicitApp)
    end

    Build!(dependent,implicitApp)
    return dependent
end

# GREEN Thread (in script)
"""
Send a newly constructed Dependent to the build system of app.
- App must be started.
"""
function Build!(dependent::T, app::AppDNA)::T where {T<:DependentDNA}
    @assert isStarted(getStarter(app)) "App is not started properly!"

    _Build!(dependent,app)
    return dependent
end

function _Build!(dependent::DependentDNA, app::AppDNA)
    build!(getModel(app),dependent)
end

function _Build!(subject::SubjectDNA, app::AppDNA)
    build!(getModel(app), subject, Dependent2Observer(app,subject))
end

