#the manager's logic is defined here, who manages the logic and graphics for juliagebra.

# ? ---------------------------------
# ! App
# ? ---------------------------------

mutable struct App <: AppDNA
    _glfw::GLFWData
    _inputs::Inputs
    _opengl::Union{OpenGLData,Nothing}
    _imgui::Union{ImGuiData,Nothing}
    _frame_limiter::Union{Nothing,FrameLimiter}
    _old_limiter::Union{Nothing,FrameLimiter}
    _cam::Camera
    _manipulator::CameraManipulator
    
    _optimizer::GlobalDependentOptimizer
    _starter::Starter
    _commander::Commander
    
    _model::Model
    _scene_change::Bool

    _asset_watcher::AssetWatcher
    _hovered::UInt32

    _delta_time::Float64
    _vsync_state::Int32

    function App(
        name::String="Juliagebra",
        width::Int32=Int32(1280),
        height::Int32=Int32(720)
    )
        glfw = GLFWData(name,width,height)
        inputs = Inputs(glfw)
        opengl = nothing
        imgui = nothing
        
        cam = defaultCamera()
        
        manipulator = create_orbital_manipulator(cam)
        optimizer = GlobalDependentOptimizer()
        starter = Starter()
        commander = Commander()
        
        model = Model()

        asset_watcher = AssetWatcher()
        hovered::UInt32 = 0

        delta_time = 0.0
        vsync_state = Int32(1)

        new(
            glfw,inputs,opengl,imgui,
            nothing,nothing,cam,manipulator,
            optimizer,starter,commander,model,false,asset_watcher,hovered,delta_time,vsync_state)
    end
end

getGLFW(self::App) = return self._glfw
getOpenGL(self::App) = return self._opengl
getDependentObservers(self::App) = getOpenGL(self)._observers
getImGui(self::App) = return self._imgui
getCommander(self::App)::Commander = return self._commander
getStarter(self::App)::Starter = return self._starter
getModel(self::App)::Model = return self._model
sceneChanged(self::App)::Nothing = (self._scene_change = true;nothing)

function resize!(self::App, event::Event)::Bool
    resize!(self._glfw, event.width, event.height)
    resize!(self._opengl, self._glfw)
    self._cam.aspect = self._glfw.width / self._glfw.height
    calculate_projection_matrix!(self._cam)
    return false
end

function window_resize!(self::App, event::Event)::Bool
    screen_resize!(self._glfw, event.width, event.height)
    resize!(self._imgui, self._glfw)
    return false
end

function mouse_move!(self::App, event::Event)
    self._hovered = readID(self._opengl,event.x,event.y,self._glfw.width,self._glfw.height)
    return false
end

function setup_callbacks(self::App)::Nothing
    register_callback!(event -> resize!(self, event), self._inputs, FRAME_RESIZE)
    register_callback!(event -> window_resize!(self, event), self._inputs, WINDOW_RESIZE)
    register_callback!(event -> mouse_move!(self, event), self._inputs, MOUSE_MOVE)
    
    register_callback!(event -> on_gizmo_left_click!(self), self._inputs, MOUSE_BUTTON_DOWN, Cint(GLFW.MOUSE_BUTTON_LEFT))
    register_callback!(event -> on_gizmo_right_click!(self), self._inputs, MOUSE_BUTTON_DOWN, Cint(GLFW.MOUSE_BUTTON_RIGHT))
    register_callback!(event -> on_gizmo_left_release!(self), self._inputs, MOUSE_BUTTON_UP,   Cint(GLFW.MOUSE_BUTTON_LEFT))
    register_callback!(event -> begin
        drag = on_gizmo_drag!(self, event)
        resize!(self._imgui._coordinatesWidget, Int(self._glfw.width), Int(self._glfw.height))
        return drag
    end, self._inputs, MOUSE_MOVE)
    
    # --- KEYBOARD DOWN EVENTS ---
    register_callback!(event -> begin
        drag = on_gizmo_drag_axis_start!(self, AXIS_X)
        resize!(self._imgui._coordinatesWidget, Int(self._glfw.width), Int(self._glfw.height))
        return drag
    end, self._inputs, KEY_DOWN, Cint(GLFW.KEY_X))
    register_callback!(event -> begin
        drag = on_gizmo_drag_axis_start!(self, AXIS_Y)
        resize!(self._imgui._coordinatesWidget, Int(self._glfw.width), Int(self._glfw.height))
        return drag
    end, self._inputs, KEY_DOWN, Cint(GLFW.KEY_Y))
    register_callback!(event -> begin
        drag = on_gizmo_drag_axis_start!(self, AXIS_Z)
        resize!(self._imgui._coordinatesWidget, Int(self._glfw.width), Int(self._glfw.height))
        return drag
    end, self._inputs, KEY_DOWN, Cint(GLFW.KEY_Z))
    
    # --- KEYBOARD UP EVENTS ---
    register_callback!(event -> on_gizmo_drag_axis_end!(self, AXIS_X), self._inputs, KEY_UP, Cint(GLFW.KEY_X))
    register_callback!(event -> on_gizmo_drag_axis_end!(self, AXIS_Y), self._inputs, KEY_UP, Cint(GLFW.KEY_Y))
    register_callback!(event -> on_gizmo_drag_axis_end!(self, AXIS_Z), self._inputs, KEY_UP, Cint(GLFW.KEY_Z))

    register_callbacks!(self._inputs, self._manipulator)
    return nothing
end

function updateCam!(self::App,delta_time::Float64)::Bool
    update!(self._manipulator, delta_time, self._inputs)
    vp = get_matrices(self._cam)[1]
    change = vp != self._opengl._last_vp
    self._opengl._last_vp = vp
    return change
end

# GREEN Thread
function play!(self::App)
    init!(self)
    notify(self._starter)

    old_time::Float64 = time()
    while(!get_shouldclose(self._glfw))
        yield()
        perf_get_results()
        new_time::Float64 = time()
        delta_time = new_time - old_time
        old_time = new_time
        update!(self._asset_watcher,delta_time)
        self._scene_change |= updateCam!(self,delta_time)
        
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
        poll_events(self._glfw)
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
    #updateGizmo!(self)
    # ? Schedule ToggleDependents, SliderDependents, TextBoxDependents and StepperDependents.
    update!(self._imgui,self)
            
    # ? Do sync! and syncAll! calls.
    self._scene_change |= update!(model,state)
            
    if !iconified
        # ? Render scene and dock.
        update!(self._opengl,self._cam,self._scene_change,self._hovered)
        render!(self._imgui,self)
        frame_end(self._opengl._profiler)
    end
end

function update!(self::App, state::BuildingState, iconified::Bool)
    model::Model = self._model
    
    # ? Do added! and addedAll! calls.
    self._scene_change |= update!(model,state)

    if !iconified
        # ? Render scene and loading bar.
        update!(self._opengl,self._cam,self._scene_change,self._hovered)
        renderBuildingState(self._imgui,self)
        frame_end(self._opengl._profiler)
    end
end

function update!(self::App, state::EvalingState, iconified::Bool)
    model::Model = self._model
    
    # ? Do sync! and syncAll! calls.
    self._scene_change |= update!(model, state)

    if !iconified
        # ? Render scene and dock.
        update!(self._opengl,self._cam,self._scene_change,self._hovered)
        render!(self._imgui,self)
        frame_end(self._opengl._profiler)
    end
end

function init!(self::App)
    if is_open(self._glfw)
        error("Window is already created, can't init! again.")
    end
    
    init!(self._glfw, true)
    self._cam.aspect = self._glfw.width / self._glfw.height
    calculate_projection_matrix!(self._cam)
    self._opengl = OpenGLData(self._glfw,self._asset_watcher)
    setup_callbacks(self)
    setup_event_handles(self._glfw,self._inputs)
    self._imgui = ImGuiData(self)
    perf_init_gpu()

    init!(self._model)
end

function destroy!(self::App)
    if !is_open(self._glfw)
        error("No window created, thus, can't destroy!")
    end

    perf_destroy_gpu()
    destroy!(self._imgui)
    destroy!(self._opengl)
    deinit!(self._glfw)
    destroy!(self._commander)
    destroy!(self._model)
end

export App
export play!
