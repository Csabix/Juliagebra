#the manager's logic is defined here, who manages the logic and graphics for juliagebra.

# ? ---------------------------------
# ! App
# ? ---------------------------------

mutable struct App <: AppDNA

    _shrd::SharedData
    _glfw::Union{GLFWData,Nothing}
    _opengl::Union{OpenGLData,Nothing}
    _imgui::Union{ImGuiData,Nothing}
    _windowCreated::Bool
    _graph::DependentGraph
    _peripherals::Peripherals
    _cam::Camera
    _manipulator::CameraManipulator
    
    _synchronizer::Synchronizer

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
        peripherals = Peripherals()
        cam = defaultCamera()
        set_aspect!(cam,width,height)
        manipulator = create_orbital_manipulator(cam)
        synchronizer = Synchronizer()
        new(shrd,glfw,opengl,imgui,windowCreated,graph,peripherals,cam,manipulator,synchronizer)
    end
end

getGLFW(self::App) = return self._glfw
getOpenGL(self::App) = return self._opengl
getImGui(self::App) = return self._imgui
getShrd(self::App) = return self._shrd
getGraph(self::App) = return self._graph
getPlanQueue(self::App) = return self._plans
getSynchronizer(self::App) = return self._synchronizer
getBuilder(self::App) = return self._builder

function keyboard_event(event::KeyboardEvent,self::App)::Nothing
    flip!(self._peripherals, event.key)
    if event.key == GLFW.KEY_ESCAPE && self._shrd._gizmoEnabled
        self._shrd._gizmoEnabled = false
        self._shrd._selectedGizmo = 0
        self._shrd._pickedID = 0
        return nothing
    end

    if event.action == GLFW.PRESS
        keyboard_down!(self._manipulator,event)
    elseif event.action == GLFW.RELEASE
        keyboard_up!(self._manipulator,event)
    end

    return nothing
end
function mouse_motion_event(event::MouseMotionEvent,self::App)::Nothing
    if mouse_motion!(self._manipulator,event) return nothing end
    self._shrd._mouseX = event.x
    self._shrd._mouseY = self._shrd._height - event.y
    self._shrd._relMouseX += event.xrel
    self._shrd._relMouseY += event.yrel
    self._shrd._mouseMoved = true

    return nothing
end
function mouse_button_event(event::MouseButtonEvent, self::App)::Nothing 
    id = readID(self._opengl, event.x, event.y)
    if gizmoSelect!(self,event,id) return nothing end
    if mouse_button!(self._manipulator,event) return nothing end

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

function updateDeltaTime!(self::App)
    currentTime = time()    
    self._shrd._deltaTime =  currentTime - self._shrd._oldTime
    self._shrd._oldTime   =  currentTime
    
end

function updateCam!(self::App)
    update!(self._manipulator, self._shrd._deltaTime, self._glfw)
    self._opengl._camPos = self._cam._eye
    vp,v,p = get_matrices(self._cam)
    
    self._opengl._vp = vp
    self._opengl._v  = v
    self._opengl._p  = p
end

function gizmoSelect!(self::App, event::MouseButtonEvent, id)::Bool
    mouse_capture = false
    if event.press
        if event.button == MOUSE_BUTTON_RIGHT
            self._shrd._pickedID = id
            if id > 3
                self._shrd._gizmoEnabled = true
                mouse_capture = true
                p = self._graph[self._shrd._pickedID]
                self._opengl._gizmoGL._pos = Vec3F(p._coord)
            else
                self._shrd._gizmoEnabled = false
            end
        elseif event.button == MOUSE_BUTTON_LEFT && self._shrd._gizmoEnabled && self._shrd._selectedGizmo == 0 && id > 0 && id<=3
            self._shrd._selectedGizmo = id
            mouse_capture = true
        end
    elseif event.button == MOUSE_BUTTON_LEFT
        self._shrd._selectedGizmo = 0
    end
    return mouse_capture
end

function updateGizmo!(self::App)
    if self._shrd._selectedGizmo != 0
        setAxisClampedT!(self._opengl._gizmoGL,self._shrd._selectedGizmo,
                    self._shrd,
                    self._opengl._vp,self._cam,self._opengl._v,self._opengl._p)
        p = self._graph[self._shrd._pickedID]
        @time_cpu_begin Graph_update
        set(
            p,
            Float64(self._opengl._gizmoGL._pos.x),
            Float64(self._opengl._gizmoGL._pos.y),
            Float64(self._opengl._gizmoGL._pos.z))
        @time_cpu_end Graph_update
    end
end

# GREEN Thread
function play!(self::App)
    
    init!(self)
    
    lock(self._synchronizer._initCondition)
    notify(self._synchronizer._initCondition)
    unlock(self._synchronizer._initCondition)
    #yield()

    while(!self._shrd._gameOver)
        yield()
        perf_get_results()
        updateDeltaTime!(self)
        updateCam!(self)
        
        state = decideFrameState(self)

        if state isa ViewingState
            
            update!(self._opengl,self._cam)
            update!(self._imgui,state)
            update!(self._shrd)
            # ? do trailing added! and addedAll! calls
            handleAddedCalls(self)
            # ? do graph updates
            updateGizmo!(self)

            unlock(self._synchronizer._lock)
        elseif state isa BuildingState
            # ? do added! and addedAll! calls
            handleAddedCalls(self)
            update!(self._opengl,self._cam)
            update!(self._imgui,state)
            update!(self._shrd)
        end

        GLFW.SwapBuffers(self._glfw._window)
        poll_events()
        self._shrd._gameOver = GLFW.WindowShouldClose(self._glfw._window)
    end
    destroy!(self)
    
end

function init!(self::App)
    if self._windowCreated
        error("Window is already created, can't init! again.")
    end
    
    self._glfw = GLFWData(self._shrd)
    self._opengl = OpenGLData(self._glfw,self._shrd)
    setInputEvents(self._glfw._window,self) # Before call to ImGUI
    self._imgui = ImGuiData(self) # After setInputEvents call
    self._windowCreated = true
    perf_init_gpu()
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
    destroy!(self._synchronizer)
end

export App
export play!
