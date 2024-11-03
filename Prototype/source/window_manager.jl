#the manager's logic is defined here, who manages the logic and graphics for juliagebra.

mutable struct Manager

    _shrd::SharedData
    _glfw::Union{GLFWData,Nothing}
    _opengl::Union{OpenGLData,Nothing}
    _imgui::Union{ImGuiData,Nothing}
    _windowCreated::Bool
    _algebra::AlgebraLogic
    _plans::Queue{RenderPlan}

    function Manager(
        name::String="Unnamed Window",
        width::Int=640,
        height::Int=480
        )

        shrd = SharedData(name,width,height)
        glfw = nothing
        opengl = nothing
        imgui = nothing
        windowCreated = false
        algebra = AlgebraLogic(shrd)
        plans = Queue{RenderPlan}()

        new(shrd,glfw,opengl,imgui,windowCreated,algebra,plans)
    end
end

function submit!(self::Manager,plan::RenderPlan)
    enqueue!(self._plans,plan)    
end

function handleEvents!(self::Manager)
    GLFW.PollEvents()
    ev = poll_event!(self._glfw._glfwEQ)
    while(!isnothing(ev))
        handleEvent!(ev,self)
        ev = poll_event!(self._glfw._glfwEQ)
    end
end

handleEvent!(self::T where T<:Event, m::Manager) = println(string(self))

function handleEvent!(ev::ResizeEvent,m::Manager)
    m._shrd._width = ev.width
    m._shrd._height = ev.height
    resize!(m._opengl)
end

function handleEvent!(ev::MouseMotionEvent,m::Manager)
    m._shrd._mouseX = ev.mouseX
    m._shrd._mouseY = m._shrd._height - ev.mouseY
    m._shrd._shouldReadID = true
end

function handlePlans!(self::Manager)
    while(!isempty(self._plans))
        asset = recruit!(self._opengl,dequeue!(self._plans))
        fuse!(self._algebra,asset)
    end
end

function play!(self::Manager)
    
    init!(self)
    while(!self._shrd._gameOver)
        update!(self._algebra)
        update!(self._opengl)
        update!(self._imgui,self._opengl)
        
        handlePlans!(self)
        handleEvents!(self)

        GLFW.SwapBuffers(self._glfw._window)
        self._shrd._gameOver = GLFW.WindowShouldClose(self._glfw._window)
    end
    destroy!(self)
    
end


function init!(self::Manager)
    if self._windowCreated
        error("Window is already created, can't init! again.")
    end
    
    self._glfw = GLFWData(self._shrd)
    self._opengl = OpenGLData(self._glfw,self._shrd)
    self._imgui = ImGuiData(self._glfw,self._opengl,self._shrd)
    self._windowCreated = true

    init!(self._algebra)
end

function destroy!(self::Manager)
    if !self._windowCreated
        error("No window created, thus, can't destroy!.")
    end

    destroy!(self._imgui)
    destroy!(self._opengl)
    destroy!(self._glfw)
    destroy!(self._algebra)
end

export Manager
export play!
export submit!

