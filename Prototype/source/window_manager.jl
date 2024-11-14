#the manager's logic is defined here, who manages the logic and graphics for juliagebra.

mutable struct Manager

    _shrd::SharedData
    _glfw::Union{GLFWData,Nothing}
    _opengl::Union{OpenGLData,Nothing}
    _imgui::Union{ImGuiData,Nothing}
    _windowCreated::Bool
    _algebra::AlgebraLogic
    _plans::Queue{RenderPlan}
    _peripherals::Peripherals
    _cam::Camera

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
        peripherals = Peripherals()
        cam = Camera()
        new(shrd,glfw,opengl,imgui,windowCreated,algebra,plans,peripherals,cam)
    end
end

function submit!(self::Manager,plan::RenderPlan)
    enqueue!(self._plans,plan)    
end

function handleEvents!(self::Manager)
    GLFW.PollEvents()
    ev = poll_event!(self._glfw._glfwEQ)
    while(!isnothing(ev))
       
        handleEvent!(self,ev)
        ev = poll_event!(self._glfw._glfwEQ)
        
    end
   
end

handleEvent!(self::Manager,ev::T where T<:Event) = println(string(ev))

function handleEvent!(self::Manager,ev::ResizeEvent)
    self._shrd._width = ev.width
    self._shrd._height = ev.height
    resize!(self._opengl)
end

function handleEvent!(self::Manager,ev::MouseMotionEvent)
    self._shrd._mouseX = ev.mouseX
    self._shrd._mouseY = self._shrd._height - ev.mouseY

    self._shrd._mouseMoved = true
end

handleEvent!(self::Manager,ev::MouseDownEvent) = flip!(self._peripherals,ev.glfw_key)

handleEvent!(self::Manager,ev::MouseUpEvent) = flip!(self._peripherals,ev.glfw_key)

handleEvent!(self::Manager,ev::KeyboardDownEvent) = flip!(self._peripherals,ev.glfw_key)

handleEvent!(self::Manager,ev::KeyboardUpEvent) = flip!(self._peripherals,ev.glfw_key)

function handlePlans!(self::Manager)
    while(!isempty(self._plans))
        asset = recruit!(self._opengl,dequeue!(self._plans))
        fuse!(self._algebra,asset)
    end
end

function updateDeltaTime!(self::Manager)
    
    currentTime = time()    
    self._shrd._deltaTime =  currentTime - self._shrd._oldTime
    self._shrd._oldTime = currentTime

end

function updateCam!(self::Manager)
    if self._peripherals._forwardHeld
        addAt!(self._cam,Vec3T{Float32}(0,1,0)*Float32(self._shrd._deltaTime)*Float32(0.1))
        self._opengl._vp = getMat(self._cam,self._shrd._width,self._shrd._height)
    end
end

function play!(self::Manager)
    
    init!(self)
    while(!self._shrd._gameOver)
        updateDeltaTime!(self)
        handlePlans!(self)
        updateCam!(self)
        update!(self._algebra)
        update!(self._opengl)
        update!(self._imgui,self._opengl,self._algebra)
        
       
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
    # ! Needed for first deltaTime to be accurate!
    updateDeltaTime!(self)
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

