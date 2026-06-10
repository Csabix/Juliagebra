#the manager's logic is defined here, who manages the logic and graphics for juliagebra.

# ? ---------------------------------
# ! App
# ? ---------------------------------

mutable struct App <: AppDNA

    _shrd::SharedData
    _glfw::Union{GLFWData,Nothing}
    _opengl::Union{OpenGLData,Nothing}
    _imgui::Union{ImGuiData,Nothing}
    _frame_limiter::Union{Nothing,FrameLimiter}
    _old_limiter::Union{Nothing,FrameLimiter}
    _windowCreated::Bool
    _peripherals::Peripherals
    _cam::Camera
    _manipulator::CameraManipulator
    
    _optimizer::GlobalDependentOptimizer
    _starter::Starter
    _commander::Commander
    
    _model::Model
    _scene_change::Bool

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
        
        peripherals = Peripherals()
        cam = defaultCamera()
        set_aspect!(cam,width,height)
        manipulator = create_orbital_manipulator(cam)
        optimizer = GlobalDependentOptimizer()
        starter = Starter()
        commander = Commander()
        
        model = Model()
                
        new(shrd,glfw,opengl,imgui,nothing,nothing,windowCreated,peripherals,cam,manipulator,optimizer,starter,commander,model,false)
    end
end

getGLFW(self::App) = return self._glfw
getOpenGL(self::App) = return self._opengl
getDependentObservers(self::App) = getOpenGL(self)._observers
getImGui(self::App) = return self._imgui
getShrd(self::App) = return self._shrd
getCommander(self::App)::Commander = return self._commander
getStarter(self::App)::Starter = return self._starter
getModel(self::App)::Model = return self._model
sceneChanged(self::App)::Nothing = (self._scene_change = true;nothing)

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
function window_focus_event(focused::Bool,self::App)::Nothing
    if focused
        self._frame_limiter = self._old_limiter
        self._old_limiter = nothing
    else
        self._old_limiter = self._frame_limiter
        self._frame_limiter = FrameLimiter(get_limit(self._old_limiter) / 2.0)
    end
    return nothing
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

function updateCam!(self::App)::Bool
    update!(self._manipulator, self._shrd._deltaTime, self._glfw)
    self._opengl._camPos = self._cam._eye
    vp,v,p = get_matrices(self._cam)
    change = vp != self._opengl._vp
    self._opengl._vp = vp
    self._opengl._v  = v
    self._opengl._p  = p
    return change
end

function gizmoSelect!(self::App, event::MouseButtonEvent, id)::Bool
    old_selected = self._shrd._selectedGizmo
    old_gizmo_enabled = self._shrd._gizmoEnabled
    old_selected = self._shrd._selectedID
    mouse_capture = false
    if event.press
        if event.button == MOUSE_BUTTON_RIGHT
            self._shrd._pickedID = id
            if id > 3 && id <= UInt32(3 + length(getNodes(getModel(self)._graph)))
                
                # ? picked id - id lower bound = graph id
                p = getDependentNode(getModel(self), self._shrd._pickedID - ID_LOWER_BOUND)
                
                if isa(p, PointDependent)
                    pp::PointDependent = p
                    self._opengl._gizmoGL._pos = Vec3F(pp._coord)
                    self._shrd._gizmoEnabled = true
                    self._shrd._gizmoConstraints = pp._constraints
                    mouse_capture = true
                else
                    self._shrd._gizmoEnabled = false
                end
            else
                self._shrd._gizmoEnabled = false
            end
        elseif event.button == MOUSE_BUTTON_LEFT && self._shrd._gizmoEnabled && self._shrd._selectedGizmo == 0 && id > 0 && id<=3
            self._shrd._selectedGizmo = id
            mouse_capture = true
        end
    elseif event.button == MOUSE_BUTTON_LEFT
        if self._shrd._selectedGizmo != 0 sceneChanged(self) end
        self._shrd._selectedGizmo = 0
    end
    self._scene_change |=   old_selected != self._shrd._selectedGizmo ||
                            old_gizmo_enabled != self._shrd._gizmoEnabled
                            old_selected != self._shrd._selectedID
    return mouse_capture
end

function updateGizmo!(self::App)
    if self._shrd._selectedGizmo != 0
        setAxisClampedT!(self._opengl._gizmoGL,self._shrd._selectedGizmo,
                    self._shrd,
                    self._opengl._vp,self._cam,self._opengl._v,self._opengl._p)
        
        # ? picked id - id lower bound = graph id
        p::PointDependent = getDependentNode(getModel(self), self._shrd._pickedID - ID_LOWER_BOUND)::PointDependent
        
        p._coord = Vec3D(
            self._opengl._gizmoGL._pos.x,
            self._opengl._gizmoGL._pos.y,
            self._opengl._gizmoGL._pos.z
            )
        # ? schedule for evalGraph
        schedule(getModel(self),p)
    end
end

# GREEN Thread
function play!(self::App)
    init!(self)
    notify(self._starter)

    while(!self._shrd._gameOver)
        yield()
        perf_get_results()
        updateDeltaTime!(self)
        self._scene_change |= updateCam!(self)
        
        model::Model = self._model
        iconified = Bool(GLFW.GetWindowAttrib(self._glfw._window, GLFW.ICONIFIED))

        # ? Begin model operations with decided state.
        state::ModelState = decideState(model)
        
        # ? Do model operations with state.
        update!(self,state,iconified)

        # ? End model state.
        endState(model,state)
        
        self._scene_change = false
        if self._frame_limiter !== nothing before_buffer_swap!(self._frame_limiter) end
        GLFW.SwapBuffers(self._glfw._window)
        if self._frame_limiter !== nothing after_buffer_swap!(self._frame_limiter) end
        poll_events()
        self._shrd._gameOver = GLFW.WindowShouldClose(self._glfw._window)
    end
    destroy!(self)
    
    global implicitApp
    if (implicitApp === self)
        implicitApp = nothing
    end
    
end

function update!(self::App, state::ViewingState, iconified::Bool)
    model::Model = self._model
    
    # ? Handle commands in the command queue.
    handleCommands!(self)
    # ? Schedule a PointDependent.
    updateGizmo!(self)
    # ? Schedule ToggleDependents, SliderDependents, TextBoxDependents and StepperDependents.
    update!(self._imgui,self)
            
    # ? Do sync! and syncAll! calls.
    self._scene_change |= update!(model,state)
            
    if !iconified
        # ? Render scene and dock.
        update!(self._opengl,self._cam,self._scene_change)
        render!(self._imgui,self)
        update!(self._shrd)
    end
end

function update!(self::App, state::BuildingState, iconified::Bool)
    model::Model = self._model
    
    # ? Do added! and addedAll! calls.
    self._scene_change |= update!(model,state)

    if !iconified
        # ? Render scene and loading bar.
        update!(self._opengl,self._cam,self._scene_change)
        renderBuildingState(self._imgui,self)
        update!(self._shrd)
    end
end

function update!(self::App, state::EvalingState, iconified::Bool)
    model::Model = self._model
    
    # ? Do sync! and syncAll! calls.
    self._scene_change |= update!(model, state)

    if !iconified
        # ? Render scene and dock.
        update!(self._opengl,self._cam,self._scene_change)
        render!(self._imgui,self)
        update!(self._shrd)
    end
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

    init!(self._model)

    # ! Needed for first deltaTime to be accurate!
    updateDeltaTime!(self)
end

function destroy!(self::App)
    if !self._windowCreated
        error("No window created, thus, can't destroy!")
    end

    perf_destroy_gpu()
    destroy!(self._imgui)
    destroy!(self._opengl)
    destroy!(self._glfw)
    destroy!(self._commander)
    destroy!(self._model)
end

export App
export play!
