#the manager's logic is defined here, who manages the logic and graphics for juliagebra.

# ? ---------------------------------
# ! App
# ? ---------------------------------

const _on_window_clear_callbacks = Vector{Function}() # Zero argument functions
on_window_clear(f::Function) = push!(_on_window_clear_callbacks,f)

mutable struct App <: AppDNA
    _glfw::GLFWData
    _inputs::Inputs
    _opengl::Union{OpenGLData,Nothing}
    _imgui::Union{ImGuiData,Nothing}
    _frame_limiter::Union{Nothing,FrameLimiter}
    _old_limiter::Union{Nothing,FrameLimiter}
    _cam::Camera
    _manipulator::CameraManipulator
    
    _optimizer::GlobalNodeOptimizer

    graph::GeometryPlotGraph
    _scene_change::Bool
    _need_clear::Bool

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
        optimizer = GlobalNodeOptimizer()

        graph = GeometryPlotGraph()

        asset_watcher = AssetWatcher()
        hovered::UInt32 = 0

        delta_time = 0.0
        vsync_state = Int32(1)

        new(
            glfw,inputs,opengl,imgui,
            nothing,nothing,cam,manipulator,
            optimizer,graph,false,false,asset_watcher,hovered,delta_time,vsync_state)
    end
end

getGLFW(self::App) = return self._glfw
getOpenGL(self::App) = return self._opengl
getDependentObservers(self::App) = getOpenGL(self)._observers
getImGui(self::App) = return self._imgui
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
    self._scene_change = true
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
    register_callback!(event ->  (recompile_shaders(self._opengl._pipeline_loader); false), self._inputs, KEY_DOWN, Cint(GLFW.KEY_F5))
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

struct GizmoPlaceHolder end
function clear!(app::App)
    for f in _on_window_clear_callbacks f() end
    clear!(app.graph)
    for _ in 1:3 add!(app.graph,GizmoPlaceHolder(),nothing,nothing,nothing,NodeFlag(0)) end
    clear!(app._opengl)
    clear!(app._optimizer)
    app._need_clear = false
end

function play!(self::App)
    old_time::Float64 = time()
    while(!get_shouldclose(self._glfw))
        yield()
        perf_get_results()
        new_time::Float64 = time()
        delta_time = new_time - old_time
        old_time = new_time
        self._delta_time = delta_time
        update!(self._asset_watcher,delta_time)
        self._scene_change |= updateCam!(self,delta_time)

        
        
        #model::Model = self._model
        iconified = Bool(GLFW.GetWindowAttrib(self._glfw._window, GLFW.ICONIFIED))

        # ? Begin model operations with decided state.
        #state::ModelState = decideState(model)
        
        # ? Do model operations with state.
        update!(self,iconified)


        # ? End model state.
        #endState(model,state)
        
        if self._frame_limiter !== nothing before_buffer_swap!(self._frame_limiter) end
        swap_buffers(self._glfw)
        if self._frame_limiter !== nothing after_buffer_swap!(self._frame_limiter) end
        poll_events(self._glfw)
        self._need_clear && clear!(self)
    end
    destroy!(self)
    
    global implicitApp
    if (implicitApp === self)
        implicitApp = nothing
    end
    
end

function update!(self::App, iconified::Bool)
    update!(self.graph, self._delta_time, NodeHandle(4))
    thread_count::Int64 = Base.Threads.nthreads()
    if thread_count == 1
        lock_read(self.graph.lck)
        try
            invokelatest(validate!,self.graph,NodeHandle(4),true)
        finally
        unlock_read(self.graph.lck)
        end
    else
        @sync begin
            for _ in 1:thread_count
                Base.Threads.@spawn begin
                    lock_read(self.graph.lck)
                    try
                        invokelatest(validate!,self.graph,NodeHandle(4),false)
                    finally
                        unlock_read(self.graph.lck)
                    end
                end
            end
            lock_read(self.graph.lck)
            try
                invokelatest(validate!,self.graph,NodeHandle(1),true)
            finally
                unlock_read(self.graph.lck)
            end
        end
    end

    self._scene_change |= render!(self.graph, self._opengl._renderers)
    update!(self._imgui,self)

    if !iconified
        # ? Render scene and dock.
        update!(self._opengl,self._cam,self._scene_change,self._hovered)
        self._scene_change = false
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
    clear!(self)
end

function destroy!(self::App)
    for f in _on_window_clear_callbacks f() end
    if !is_open(self._glfw)
        error("No window created, thus, can't destroy!")
    end

    perf_destroy_gpu()
    destroy!(self._imgui)
    destroy!(self._opengl)
    deinit!(self._glfw)
end

export App
export play!
