#the manager's logic is defined here, who manages the logic and graphics for juliagebra.

global implicitApp = nothing

mutable struct App

    _shrd::SharedData
    _glfw::Union{GLFWData,Nothing}
    _opengl::Union{OpenGLData,Nothing}
    _imgui::Union{ImGuiData,Nothing}
    _windowCreated::Bool
    _algebra::AlgebraLogic
    _plans::Queue{PlanDNA}
    _peripherals::Peripherals
    _cam::Camera

    function App(
        name::String="Juliagebra",
        width::Int=1280,
        height::Int=720
        )

        shrd = SharedData(name,width,height)
        glfw = nothing
        opengl = nothing
        imgui = nothing
        windowCreated = false
        algebra = AlgebraLogic(shrd)
        plans = Queue{PlanDNA}()
        peripherals = Peripherals()
        cam = Camera()
        self = new(shrd,glfw,opengl,imgui,windowCreated,algebra,plans,peripherals,cam)

        global implicitApp
        implicitApp = self
        return self
    end
end

function submit!(self::App,plan::PlanDNA)
    enqueue!(self._plans,plan)    
end

function handleEvents!(self::App)
    GLFW.PollEvents()
    ev = poll_event!(self._glfw._glfwEQ)
    # TODO: Lusta esemenykuldes
    while(!isnothing(ev))
        handleEvent!(self,ev)
        ev = poll_event!(self._glfw._glfwEQ)
        
    end
end

handleEvent!(self::App,ev::T where T<:Event) = println(string(ev))

function handleEvent!(self::App,ev::ResizeEvent)
    self._shrd._width = ev.width
    self._shrd._height = ev.height
    resize!(self._opengl)
    resize!(self._imgui)
end

function handleEvent!(self::App,ev::MouseMotionEvent)
    self._shrd._mouseX = ev.mouseX
    self._shrd._mouseY = self._shrd._height - ev.mouseY
    self._shrd._relMouseX += ev.xrel
    self._shrd._relMouseY += ev.yrel
    self._shrd._mouseMoved = true
end

function handleEvent!(self::App,ev::MouseWheelEvent)
    self._shrd._wheelUpDown = -ev.wheelY
    self._shrd._wheelMoved = true
end

handleEvent!(self::App,ev::MouseDownEvent) = flip!(self._peripherals,ev.glfw_key)

handleEvent!(self::App,ev::MouseUpEvent) = flip!(self._peripherals,ev.glfw_key)

handleEvent!(self::App,ev::KeyboardDownEvent) = flip!(self._peripherals,ev.glfw_key)

handleEvent!(self::App,ev::KeyboardUpEvent) = flip!(self._peripherals,ev.glfw_key)

function handlePlans!(self::App)
    while(!isempty(self._plans))
        asset = recruit!(self._opengl,dequeue!(self._plans))
        fuse!(self._algebra,asset)
    end
end

function updateDeltaTime!(self::App)
    
    currentTime = time()    
    self._shrd._deltaTime =  currentTime - self._shrd._oldTime
    self._shrd._oldTime   =  currentTime
    
end

function updateCam!(self::App)
    dt = self._shrd._deltaTime
    if self._peripherals._middleHeld && self._shrd._mouseMoved
        lr = self._shrd._relMouseX
        ud = self._shrd._relMouseY
        if self._peripherals._mod1Held
            moveAt!(self._cam,Float32(0.0),Float32(lr),Float32(-ud),dt)
        else
            sensitivityRot!(self._cam,Float32(lr),Float32(ud),dt)
        end
    end

        

    if self._shrd._wheelMoved
        sensitivityZoom(self._cam,Float32(self._shrd._wheelUpDown),dt)
    end

    if self._peripherals._forwardHeld
        moveAt!(self._cam,Float32(1.0),Float32(0.0),Float32(0.0),dt)
    end
    
    self._opengl._camPos = self._cam._eye
    vp,v,p = getMat(self._cam,self._shrd._width,self._shrd._height)
    
    self._opengl._vp = vp
    self._opengl._v  = v
    self._opengl._p  = p


end

function updateGizmo!(self::App)
    
    id = self._shrd._selectedID
    
    if(self._peripherals._bHeld)
        self._shrd._pickedID = id
        if(id>3)
            self._shrd._gizmoEnabled = true
            p = fetch(self._algebra,self._shrd._pickedID)
            self._opengl._gizmoGL._pos = Vec3F(p._x,p._y,p._z)
        else
            self._shrd._gizmoEnabled = false  
        end
    end

    if(!self._shrd._gizmoEnabled)
        return
    end

    if self._peripherals._aHeld
        if self._shrd._selectedGizmo == 0
            if (id > 0) && (id<=3)
                self._shrd._selectedGizmo = id
            end
        else
            setAxisClampedT!(self._opengl._gizmoGL,self._shrd._selectedGizmo,
                        self._shrd,
                        self._opengl._vp,self._cam,self._opengl._v,self._opengl._p)
            p = fetch(self._algebra,self._shrd._pickedID)      
            set(
                p,
                Float64(self._opengl._gizmoGL._pos.x),
                Float64(self._opengl._gizmoGL._pos.y),
                Float64(self._opengl._gizmoGL._pos.z))
        end
    else
       self._shrd._selectedGizmo = 0
    end
end

function play!(self::App)
    
    init!(self)
    while(!self._shrd._gameOver)
        
        updateDeltaTime!(self)
        handlePlans!(self)
        updateCam!(self)
        
        update!(self._algebra)
        update!(self._opengl)
        update!(self._imgui,self._opengl,self._algebra,self._cam)
        update!(self._shrd)
        updateGizmo!(self)
       
        handleEvents!(self)
        
        GLFW.SwapBuffers(self._glfw._window)
        self._shrd._gameOver = GLFW.WindowShouldClose(self._glfw._window)
    end
    destroy!(self)
    
end

play!() = play!(implicitApp)

function init!(self::App)
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

function destroy!(self::App)
    if !self._windowCreated
        error("No window created, thus, can't destroy!.")
    end

    destroy!(self._imgui)
    destroy!(self._opengl)
    destroy!(self._glfw)
    destroy!(self._algebra)
end

export App
export play!
