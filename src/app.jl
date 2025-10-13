#the manager's logic is defined here, who manages the logic and graphics for juliagebra.

global implicitApp = nothing

mutable struct App

    _shrd::SharedData
    _glfw::Union{GLFWData,Nothing}
    _opengl::Union{OpenGLData,Nothing}
    _imgui::Union{ImGuiData,Nothing}
    _windowCreated::Bool
    _graph::DependentGraph
    _plans::Queue{PlanDNA}
    _peripherals::Peripherals
    _cam::Camera
    _manipulator::CameraManipulator

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
        graph = DependentGraph()
        plans = Queue{PlanDNA}()
        peripherals = Peripherals()
        cam = defaultCamera()
        set_aspect!(cam,width,height)
        manipulator = create_orbital_manipulator(cam)
        self = new(shrd,glfw,opengl,imgui,windowCreated,graph,plans,peripherals,cam,manipulator)

        global implicitApp
        implicitApp = self
        return self
    end
end

function submit!(self::App,plan::PlanDNA)
    enqueue!(self._plans,plan)    
end

function keyboard_event(event::KeyboardEvent,self::App)::Nothing
    flip!(self._peripherals, event.key)

    if event.action == GLFW.PRESS
        keyboard_down!(self._manipulator,event)
    elseif event.action == GLFW.RELEASE
        keyboard_up!(self._manipulator,event)
    end

    return nothing
end
function mouse_motion_event(event::MouseMotionEvent,self::App)::Nothing
    self._shrd._mouseX = event.x
    self._shrd._mouseY = self._shrd._height - event.y
    self._shrd._relMouseX += event.xrel
    self._shrd._relMouseY += event.yrel
    self._shrd._mouseMoved = true

    mouse_motion!(self._manipulator,event)
    return nothing
end
function mouse_button_event(event::MouseButtonEvent, self::App)::Nothing 
    id = readID(self._opengl, event.x, event.y)
    mouse_button!(self._manipulator,event,id)
    if event.press
        if event.button == MOUSE_BUTTON_LEFT
            self._peripherals._aHeld = true
        elseif event.button == MOUSE_BUTTON_RIGHT
            self._peripherals._bHeld = true
        elseif event.button == MOUSE_BUTTON_MIDDLE
            self._peripherals._middleHeld = true
        end
    else
        if event.button == MOUSE_BUTTON_LEFT
            self._peripherals._aHeld = false
        elseif event.button == MOUSE_BUTTON_RIGHT
            self._peripherals._bHeld = false
        elseif event.button == MOUSE_BUTTON_MIDDLE
            self._peripherals._middleHeld = false
        end
    end
    return nothing
end
function mouse_wheel_event(event::MouseWheelEvent,self::App)::Nothing
    self._shrd._wheelUpDown = -event.yoffset
    self._shrd._wheelMoved = true

    mouse_wheel!(self._manipulator,event)
    return nothing
end
function window_resize_event(width::Cint,height::Cint,self::App)::Nothing
    self._shrd._width = width
    self._shrd._height = height
    resize!(self._opengl)
    resize!(self._imgui)
    set_aspect!(self._cam,width,height)
end
function framebuffer_resize_event(width::Cint,height::Cint,self::App)::Nothing
    
end

function can_capture_keys(self::App)::Bool
    return !captures_keyboard(self._imgui)
end
function can_capture_mouse(self::App)::Bool
    return !captures_mouse(self._imgui)
end

function handlePlans!(self::App)
    observers = Set{ObserverDNA}()

    while(!isempty(self._plans))
        observer = build!(self,dequeue!(self._plans)) 
        
        if (!isnothing(observer))
            push!(observers,observer)
        end
        
    end

    for observer in observers
        addedAll!(observer)
    end
end


function build!(self::App, plan::PlanDNA) 
   dependent = buildFromPlan!(plan,self._graph)
   return nothing
end


function build!(self::App, plan::GuiPlanDNA)
    observer,observed = buildFromPlan!(plan,self._graph,self._imgui)
    return observer
end

function build!(self::App, plan::RenderedPlanDNA)
    renderer,observed = buildFromPlan!(plan,self._graph,self._opengl)
    setRenderedID!(renderer,observed,getGraphID(observed) + ID_LOWER_BOUND)
    return renderer
end

function updateDeltaTime!(self::App)
    currentTime = time()    
    self._shrd._deltaTime =  currentTime - self._shrd._oldTime
    self._shrd._oldTime   =  currentTime
    
end

function updateCam!(self::App)
    update!(self._manipulator, self._shrd._deltaTime)
    self._opengl._camPos = self._cam._eye
    vp,v,p = get_matrices(self._cam)
    
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
            p = fetch(self._graph,self._shrd._pickedID)
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
            p = fetch(self._graph,self._shrd._pickedID)      
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
        
        update!(self._opengl,self._cam)
        update!(self._imgui)
        update!(self._shrd)
        updateGizmo!(self)
       
        
        GLFW.SwapBuffers(self._glfw._window)
        poll_events()
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
    setInputEvents(self._glfw._window,self) # Before call to ImGUI
    self._imgui = ImGuiData(self._glfw,self._opengl,self._shrd) # After setInputEvents call
    self._windowCreated = true

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
end

export App
export play!
