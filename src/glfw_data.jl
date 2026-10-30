mutable struct GLFWData
    name::String
    _window::GLFW.Window
    width::Int32
    height::Int32
    s_width::Int32
    s_height::Int32
    scale::Float32

    # For non-blocking backbuffer swap
    _swap_request::Base.Event
    _swap_done::Base.Event
    _swap_task::Any
    _closing::Bool

    function GLFWData(name::String,inital_width::Int32,inital_height::Int32)
        return new(
            name,GLFW.Window(C_NULL),0,0,inital_width,inital_height,0.0f0,
            Base.Event(true),Base.Event(true),nothing,false
        )
    end
end

const KEY_DOWN::UInt8           = 0x01
const KEY_UP::UInt8             = 0x02
const MOUSE_MOVE::UInt8         = 0x03
const MOUSE_BUTTON_DOWN::UInt8  = 0x04
const MOUSE_BUTTON_UP::UInt8    = 0x05
const MOUSE_WHEEL::UInt8        = 0x06
const FRAME_RESIZE::UInt8       = 0x07
const WINDOW_RESIZE::UInt8      = 0x08

const KEY_MOD_NONE::UInt8       = 0x00
const KEY_MOD_SHIFT::UInt8      = 0x01
const KEY_MOD_CONTROL::UInt8    = 0x02
const KEY_MOD_ALT::UInt8        = 0x04
const KEY_MOD_SUPER::UInt8      = 0x08

@enum InputAction::UInt32 begin
    ACTION_CAM_FORWARD
    ACTION_CAM_BACK
    ACTION_CAM_LEFT
    ACTION_CAM_RIGHT
    ACTION_CAM_UP
    ACTION_CAM_DOWN
    ACTION_SET_VIEW_AXIS_POS_X
    ACTION_SET_VIEW_AXIS_NEG_X
    ACTION_SET_VIEW_AXIS_POS_Y
    ACTION_SET_VIEW_AXIS_NEG_Y
    ACTION_SET_VIEW_AXIS_POS_Z
    ACTION_SET_VIEW_AXIS_NEG_Z
    ACTION_FLIP_VIEW
    ACTION_SWAP_PROJECTION_MODE
end

struct Event
    type::UInt8
    key_mod::UInt8
    scancode::Cint
    x::Cdouble
    y::Cdouble
    dx::Cdouble
    dy::Cdouble
    width::Cint
    height::Cint
end

mutable struct Inputs
    event_callbacks::SVector{8,Vector{Tuple{UInt8,Function}}}
    last_x::Cdouble
    last_y::Cdouble
    window::GLFWData

    scratch_path::String
    toml_file::String

    action_map::Dict{Tuple{UInt8, Cint}, InputAction} # mod + keycode -> action
    reverse_action_map::Dict{InputAction, Vector{Tuple{UInt8, Cint}}}

    pause_key_callbacks::Bool

    button_press::Dict{Cint,Vector{Tuple{UInt8,Function}}}
    button_release::Dict{Cint,Vector{Tuple{UInt8,Function}}}
    mouse_press::Dict{Cint,Vector{Tuple{UInt8,Function}}}
    mouse_release::Dict{Cint,Vector{Tuple{UInt8,Function}}}

    keys_pressed::Dict{GLFW.Key, Event}
    keys_held::Dict{GLFW.Key, Event}
    keys_released::Dict{GLFW.Key, Event}

    action_handler_map::Dict{Tuple{UInt8, InputAction}, Vector{Function}} # type + action -> handler
    handle_map::Vector{Tuple{UInt8,Cint,UInt8,Function}}

    function Inputs(window::GLFWData)
        path = "input_map"
        file = "inputs.toml"
        scratch = @get_scratch!(path)
        println("keybinds file: $scratch/$file")
        kb = load_keybinds("$scratch/$file")
        rkb = Dict{InputAction, Vector{Tuple{UInt8, Cint}}}()
        for k in keys(kb)
            if haskey(rkb, kb[k])
                push!(rkb[kb[k]], k)
            else
                rkb[kb[k]] = [k]
            end
        end

        rt = new(
            SVector{8}([Vector{Tuple{UInt8,Function}}() for _ in 1:8]), 
            0.0,
            0.0,
            window,
            path,
            file,
            kb,
            rkb,
            false,
            Dict{Cint, Vector{Tuple{UInt8,Function}}}(),
            Dict{Cint, Vector{Tuple{UInt8,Function}}}(),
            Dict{Cint, Vector{Tuple{UInt8,Function}}}(),
            Dict{Cint, Vector{Tuple{UInt8,Function}}}(),
            Dict{GLFW.Key, Event}(),
            Dict{GLFW.Key, Event}(),
            Dict{GLFW.Key, Event}(),
            Dict{Tuple{UInt8, InputAction}, Vector{Function}}(),
            Vector{Tuple{UInt8,Cint,UInt8,Function}}()
        )
        save_keybinds(rt)
        return rt
    end
end

function init!(w::GLFWData,debug::Bool)::Nothing
    GLFW.WindowHint(GLFW.DOUBLEBUFFER , 1);
    GLFW.WindowHint(GLFW.DEPTH_BITS, 24);
    GLFW.WindowHint(GLFW.STENCIL_BITS, 8);

    GLFW.WindowHint(GLFW.CONTEXT_VERSION_MAJOR, 4)
    GLFW.WindowHint(GLFW.CONTEXT_VERSION_MINOR, 6)
    GLFW.WindowHint(GLFW.OPENGL_PROFILE, GLFW.OPENGL_CORE_PROFILE);
    GLFW.WindowHint(GLFW.OPENGL_DEBUG_CONTEXT, debug)
    
    window = GLFW.CreateWindow(w.s_width,w.s_height,w.name)

    if window.handle == C_NULL
        error("GLFW window creation failed.")
    end
    
    GLFW.MakeContextCurrent(window)
    GLFW.SwapInterval(1)

    (buffer_w,buffer_h) = GLFW.GetFramebufferSize(window)
    (x_scale,_) = GLFW.GetWindowContentScale(window)
    w._window = window
    w.width = buffer_w
    w.height = buffer_h
    w.scale = x_scale

    start_swap_thread!(w)
    return nothing
end

is_open(window::GLFWData) = return window._window.handle != C_NULL

function get_input_action_name(action::InputAction)
    return "$action"
end

function deinit!(w::GLFWData)
    stop_swap_thread!(w)
    GLFW.DestroyWindow(w._window)
    w._window   = GLFW.Window(C_NULL)
    w.width     = Int32(0)
    w.height    = Int32(0)
    w.s_width   = Int32(0)
    w.s_height  = Int32(0)
end

get_shouldclose(w::GLFWData)::Bool = GLFW.WindowShouldClose(w._window)
set_shouldclose(w::GLFWData,should_close::Bool)::Nothing = (GLFW.SetWindowShouldClose(w._window,should_close); nothing)
get_resolution(w::GLFWData)::Tuple{Int32,Int32} = tuple(w.width,w.height)

function poll_events(::GLFWData, inputs::Inputs)::Nothing
    inputs.keys_pressed = Dict()
    inputs.keys_released = Dict()
    GLFW.PollEvents()
end

function _swap_loop(w::GLFWData)::Nothing
    window = w._window
    while true
        wait(w._swap_request)
        if w._closing
            return nothing
        end
        GLFW.MakeContextCurrent(window)
        GLFW.SwapBuffers(window)
        GLFW.MakeContextCurrent(GLFW.Window(C_NULL))
        notify(w._swap_done)
    end
end

function start_swap_thread!(w::GLFWData)::Nothing
    w._closing = false
    if Base.Threads.nthreads() > 1
        swap_tid = 2
        w._swap_task = ThreadPinning.@spawnat swap_tid _swap_loop(w)
    else
        w._swap_task = Base.Threads.@spawn _swap_loop(w)
    end
    errormonitor(w._swap_task)
    return nothing
end

function stop_swap_thread!(w::GLFWData)::Nothing
    if w._swap_task === nothing
        return nothing
    end
    w._closing = true
    notify(w._swap_request)
    wait(w._swap_task)
    w._swap_task = nothing
    return nothing
end

function swap_buffers(w::GLFWData,blocking=false)::Nothing
    if blocking
        GLFW.SwapBuffers(w._window)
        return nothing
    end
    GLFW.MakeContextCurrent(GLFW.Window(C_NULL))
    notify(w._swap_request)
    wait(w._swap_done)
    GLFW.MakeContextCurrent(w._window)
    return nothing
end

function resize!(w::GLFWData, width::Cint, height::Cint)::Bool
    w.width = Int32(width)
    w.height = Int32(height)
    return false
end

function screen_resize!(w::GLFWData, width::Cint, height::Cint)::Bool
    w.s_width = Int32(width)
    w.s_height = Int32(height)
    return false
end

function disable_mouse(inputs::Inputs)
    GLFW.SetInputMode(inputs.window._window, GLFW.CURSOR, GLFW.CURSOR_DISABLED);
end
function enable_mouse(inputs::Inputs)
    (inputs.last_x,inputs.last_y) = GLFW.GetCursorPos(inputs.window._window)
    GLFW.SetInputMode(inputs.window._window, GLFW.CURSOR, GLFW.CURSOR_NORMAL);
end

function _rebuild_inputs!(inputs::Inputs)::Nothing
    foreach(empty!,inputs.event_callbacks)

    empty!(inputs.button_press)
    empty!(inputs.button_release)
    empty!(inputs.mouse_press)
    empty!(inputs.mouse_release)

    for (type, code, mod, func) in inputs.handle_map
        push!(inputs.event_callbacks[type], (mod, func))
        
        if type in (KEY_DOWN, KEY_UP, MOUSE_BUTTON_DOWN, MOUSE_BUTTON_UP)
            dict = if type == KEY_DOWN; inputs.button_press
                   elseif type == KEY_UP; inputs.button_release
                   elseif type == MOUSE_BUTTON_DOWN; inputs.mouse_press
                   else; inputs.mouse_release end
            
            vec = get!(dict, code, Tuple{UInt8, Function}[])
            push!(vec, (mod, func))
        end
    end
    return nothing
end

function load_keybinds(path::String)::Dict{Tuple{UInt8, Cint}, InputAction}
    if isfile(path)
        d = TOML.parsefile(path)
        rt::Dict{Tuple{UInt8, Cint}, InputAction} = Dict()
        for i in eachindex(d["keys"])
            k = d["keys"][i]
            k = (UInt8(k[1]), Cint(k[2]))
            rt[k] = InputAction(d["values"][i])
        end
        return rt
    else
        rt = default_keybinds()
        save_keybinds(rt, path)
        return rt
    end
end

function save_keybinds(inputs::Inputs)
    save_keybinds(inputs.action_map, @get_scratch!(inputs.scratch_path)*"/"*inputs.toml_file)
end

function save_keybinds(map::Dict{Tuple{UInt8, Cint}, InputAction}, path::String)
    path = touch(path)
    file = open(path, "w")
    dict = Dict{String, Any}(
        "keys" => [],
        "values" => []
    )

    for k in keys(map)
        push!(dict["keys"], [k[1], k[2]])
        push!(dict["values"], UInt32(map[k]))
    end

    TOML.print(file, dict)
    close(file)
end

function default_keybinds()::Dict{Tuple{UInt8, Cint}, InputAction}
    return Dict{Tuple{UInt8, Cint}, InputAction}(
        (KEY_MOD_NONE, Cint(GLFW.KEY_W)) => ACTION_CAM_FORWARD,
        (KEY_MOD_NONE, Cint(GLFW.KEY_UP)) => ACTION_CAM_FORWARD,

        (KEY_MOD_NONE, Cint(GLFW.KEY_D)) => ACTION_CAM_RIGHT,
        (KEY_MOD_NONE, Cint(GLFW.KEY_RIGHT)) => ACTION_CAM_RIGHT,

        (KEY_MOD_NONE, Cint(GLFW.KEY_S)) => ACTION_CAM_BACK,
        (KEY_MOD_NONE, Cint(GLFW.KEY_DOWN)) => ACTION_CAM_BACK,

        (KEY_MOD_NONE, Cint(GLFW.KEY_A)) => ACTION_CAM_LEFT,
        (KEY_MOD_NONE, Cint(GLFW.KEY_LEFT)) => ACTION_CAM_LEFT,

        (KEY_MOD_NONE, Cint(GLFW.KEY_Q)) => ACTION_CAM_DOWN,
        (KEY_MOD_NONE, Cint(GLFW.KEY_E)) => ACTION_CAM_UP,

        (KEY_MOD_NONE, Cint(GLFW.KEY_KP_9)) => ACTION_FLIP_VIEW,

        (KEY_MOD_NONE, Cint(GLFW.KEY_KP_7)) => ACTION_SET_VIEW_AXIS_POS_Y,
        (KEY_MOD_ALT, Cint(GLFW.KEY_KP_7)) => ACTION_SET_VIEW_AXIS_NEG_Y,

        (KEY_MOD_NONE, Cint(GLFW.KEY_KP_1)) => ACTION_SET_VIEW_AXIS_POS_Z,
        (KEY_MOD_ALT, Cint(GLFW.KEY_KP_1)) => ACTION_SET_VIEW_AXIS_NEG_Z,

        (KEY_MOD_NONE, Cint(GLFW.KEY_KP_3)) => ACTION_SET_VIEW_AXIS_POS_X,
        (KEY_MOD_ALT, Cint(GLFW.KEY_KP_3)) => ACTION_SET_VIEW_AXIS_NEG_X,

        (KEY_MOD_NONE, Cint(GLFW.KEY_KP_5)) => ACTION_SWAP_PROJECTION_MODE,
    )
end

function set_action_input(inputs::Inputs, action::InputAction, code::Cint, mod::UInt8 = KEY_MOD_NONE)
    if haskey(inputs.action_map, (mod, code))
        delete_action_input(inputs, code, mod)
    end
    inputs.action_map[(mod, code)] = action
    
    if haskey(inputs.reverse_action_map, action)
        push!(inputs.reverse_action_map[action], (mod, code))
    else
        inputs.reverse_action_map[action] = [(mod, code)]
    end
    save_keybinds(inputs)
end

function keypress_name(mod::UInt8, key::Cint)::String
    rt = ""
    if mod & KEY_MOD_CONTROL == KEY_MOD_CONTROL
        rt *= "Ctrl + "
    end
    if mod & KEY_MOD_ALT == KEY_MOD_ALT
        rt *= "Alt + "
    end
    if mod & KEY_MOD_SHIFT == KEY_MOD_SHIFT
        rt *= "Shift + "
    end
    if mod & KEY_MOD_SUPER == KEY_MOD_SUPER
        rt *= "Win + "
    end
    name = GLFW.Key(key)
    name = "$name"
    name = collect(String(name[5:end]))
    replace!(name, '_'=>' ')
    name = String(name)
    name = titlecase(name)
    rt *= name
    return rt
end

function is_valid_key(key::GLFW.Key)
    return (
        key != GLFW.KEY_LEFT_ALT &&
        key != GLFW.KEY_RIGHT_ALT &&
        key != GLFW.KEY_LEFT_SHIFT &&
        key != GLFW.KEY_RIGHT_SHIFT &&
        key != GLFW.KEY_LEFT_CONTROL &&
        key != GLFW.KEY_RIGHT_CONTROL &&
        key != GLFW.KEY_LEFT_SUPER &&
        key != GLFW.KEY_RIGHT_SUPER
    )
end

function delete_action_input(inputs::Inputs, code::Cint, mod::UInt8 = KEY_MOD_NONE)
    action = inputs.action_map[(mod, code)]
    deleteat!(inputs.reverse_action_map[action], indexin([(mod, code)], inputs.reverse_action_map[action])[1])
    delete!(inputs.action_map, (mod, code))

    save_keybinds(inputs)
end

function register_callback!(func::Function, inputs::Inputs, type::UInt8, code::Cint = Cint(0), mod::UInt8 = UInt8(KEY_MOD_NONE))::Int32
    push!(inputs.handle_map, (type, Cint(code), mod, func))
    push!(inputs.event_callbacks[type], (mod, func))
    if type in (KEY_DOWN, KEY_UP, MOUSE_BUTTON_DOWN, MOUSE_BUTTON_UP)
        dict = if type == KEY_DOWN; inputs.button_press
               elseif type == KEY_UP; inputs.button_release
               elseif type == MOUSE_BUTTON_DOWN; inputs.mouse_press
               else; inputs.mouse_release end
            
        vec = get!(dict, code, Tuple{UInt8, Function}[])
        push!(vec, (mod, func))
    end
    return Int32(length(inputs.handle_map))
end

function register_callback_for_action(func::Function, inputs::Inputs, type::UInt8, action::InputAction)
    @assert type in (KEY_UP, KEY_DOWN) "input actions only upport keyboard events"
    vec = get!(inputs.action_handler_map, (type, action), [])
    push!(vec, func)
end

function change_callback!(func::Function, inputs::Inputs, handle::Int32, type::UInt8; code::Cint = 0, mod::UInt8 = KEY_MOD_NONE)::Nothing
    inputs.handle_map[handle] = (type, Cint(code), mod, func)
    _rebuild_inputs!(inputs)
    return nothing
end

function _input_call(inputs::Inputs,event::Event)::Nothing
    callbacks::Vector{Tuple{UInt8, Function}} = if event.type == KEY_DOWN
        if haskey(inputs.button_press,event.scancode)
            inputs.button_press[event.scancode]
        else
            Tuple{UInt8, Function}[]
        end
    elseif event.type == KEY_UP
        if haskey(inputs.button_release,event.scancode)
            inputs.button_release[event.scancode]
        else
            Tuple{UInt8, Function}[]
        end
    elseif event.type == MOUSE_MOVE
        inputs.event_callbacks[MOUSE_MOVE]
    elseif event.type == MOUSE_BUTTON_DOWN
        if haskey(inputs.mouse_press,event.scancode)
            inputs.mouse_press[event.scancode]
        else
            Tuple{UInt8, Function}[]
        end
    elseif event.type == MOUSE_BUTTON_UP
        if haskey(inputs.mouse_release,event.scancode)
            inputs.mouse_release[event.scancode]
        else
            Tuple{UInt8, Function}[]
        end
    elseif event.type == MOUSE_WHEEL
        inputs.event_callbacks[MOUSE_WHEEL]
    elseif event.type == FRAME_RESIZE
        inputs.event_callbacks[FRAME_RESIZE]
    elseif event.type == WINDOW_RESIZE
        inputs.event_callbacks[WINDOW_RESIZE]
    end

    for (mod,callback) in callbacks
        if (event.key_mod & mod) == mod
            if callback(event)
                break
            end
        end
    end

    if event.type in (KEY_DOWN, KEY_UP) && haskey(inputs.action_map, (event.key_mod, event.scancode))
        action = inputs.action_map[(event.key_mod, event.scancode)]
        for callback in get(inputs.action_handler_map, (event.type, action), [])
            if callback(action, event)
                break
            end
        end
    end
    return nothing
end

function _key_callback(window::GLFW.Window, key::GLFW.Key, scancode::Cint, action::GLFW.Action, mods::Cint, inputs::Inputs)::Nothing
    io_ptr = CImGui.GetIO()
    io = unsafe_load(io_ptr)
    if io.WantCaptureKeyboard return nothing end
    event::Event = Event(
        action == GLFW.RELEASE ? KEY_UP : KEY_DOWN,
        UInt8(mods),
        Cint(key),
        0.0,0.0,
        0.0,0.0,
        Cint(0),Cint(0)
    )

    if event.type == KEY_UP
        delete!(inputs.keys_held, key)
        inputs.keys_released[key] = event
    else
        if !haskey(inputs.keys_held, key)
            inputs.keys_pressed[key] = event
        end
        inputs.keys_held[key] = event
    end

    if inputs.pause_key_callbacks
        return
    end

    _input_call(inputs,event)
end

function _mouse_move_callback(w::GLFWData, window::GLFW.Window, xpos::Cdouble, ypos::Cdouble, inputs::Inputs)::Nothing
    io_ptr = CImGui.GetIO()
    io = unsafe_load(io_ptr)
    if io.WantCaptureMouse return nothing end
    ypos = Cdouble(w.height) - ypos
    event::Event = Event(
        MOUSE_MOVE,
        0x00,
        Cint(0),
        xpos,ypos,
        xpos - inputs.last_x,ypos - inputs.last_y,
        Cint(0),Cint(0)
    )
    inputs.last_x = xpos
    inputs.last_y = ypos

    _input_call(inputs,event)
end

function _mouse_button_callback(window::GLFW.Window, button::GLFW.MouseButton, action::GLFW.Action, mods::Cint, inputs::Inputs)::Nothing
    io_ptr = CImGui.GetIO()
    io = unsafe_load(io_ptr)
    if io.WantCaptureMouse return nothing end
    type = action == GLFW.PRESS ? MOUSE_BUTTON_DOWN : MOUSE_BUTTON_UP

    event::Event = Event(
        type,
        UInt8(mods),
        Cint(button),
        inputs.last_x,inputs.last_y,
        0.0,0.0,
        Cint(0),Cint(0)
    )

    _input_call(inputs,event)
end

function _scroll_callback(window::GLFW.Window, xoffset::Cdouble, yoffset::Cdouble, inputs::Inputs)::Nothing
    io_ptr = CImGui.GetIO()
    io = unsafe_load(io_ptr)
    if io.WantCaptureMouse return nothing end
    event::Event = Event(
        MOUSE_WHEEL,
        0x00,
        Cint(0),
        inputs.last_x,inputs.last_y,
        xoffset,yoffset,
        Cint(0),Cint(0)
    )

    _input_call(inputs,event)
end

function _frame_resize_callback(window::GLFW.Window, width::Cint, height::Cint, inputs::Inputs)::Nothing
    event::Event = Event(
        FRAME_RESIZE,
        0x00,
        Cint(0),
        0.0,0.0,
        0.0,0.0,
        width,height
    )

    _input_call(inputs,event)
end

function _window_resize_callback(window::GLFW.Window, width::Cint, height::Cint, inputs::Inputs)::Nothing
    event::Event = Event(
        WINDOW_RESIZE,
        0x00,
        Cint(0),
        0.0,0.0,
        0.0,0.0,
        width,height
    )

    _input_call(inputs,event)
end

precompile(_key_callback, (GLFW.Window, GLFW.Key, Cint, GLFW.Action, Cint, Inputs))
precompile(_mouse_move_callback, (GLFW.Window, Cdouble, Cdouble, Inputs))
precompile(_mouse_button_callback, (GLFW.Window, GLFW.MouseButton, GLFW.Action, Cint, Inputs))
precompile(_scroll_callback, (GLFW.Window, Cdouble, Cdouble, Inputs))
precompile(_frame_resize_callback, (GLFW.Window, Cint, Cint, Inputs))
precompile(_window_resize_callback, (GLFW.Window, Cint, Cint, Inputs))

function setup_event_handles(window::GLFWData,inputs::Inputs)::Nothing
    (inputs.last_x,inputs.last_y) = GLFW.GetCursorPos(window._window)

    key_callback = (window_ptr::GLFW.Window,key::GLFW.Key,scancode::Cint,action::GLFW.Action,mods::Cint) -> _key_callback(window_ptr,key,scancode,action,mods,inputs)
    GLFW.SetKeyCallback(window._window,key_callback)

    mouse_move_callback = (window_ptr::GLFW.Window,xpos::Cdouble,ypos::Cdouble) -> _mouse_move_callback(window,window_ptr,xpos,ypos,inputs)
    GLFW.SetCursorPosCallback(window._window,mouse_move_callback)

    mouse_button_callback = (window_ptr::GLFW.Window,button::GLFW.MouseButton,action::GLFW.Action,mods::Cint) -> _mouse_button_callback(window_ptr,button,action,mods,inputs)
    GLFW.SetMouseButtonCallback(window._window,mouse_button_callback)

    scroll_callback = (window_ptr::GLFW.Window,xoffset::Cdouble,yoffset::Cdouble) -> _scroll_callback(window_ptr,xoffset,yoffset,inputs)
    GLFW.SetScrollCallback(window._window,scroll_callback)

    frame_callback = (window_ptr::GLFW.Window,width::Cint,height::Cint) -> _frame_resize_callback(window_ptr,width,height,inputs)
    GLFW.SetFramebufferSizeCallback(window._window,frame_callback)

    window_callback = (window_ptr::GLFW.Window,width::Cint,height::Cint) -> _window_resize_callback(window_ptr,width,height,inputs)
    GLFW.SetWindowSizeCallback(window._window,window_callback)

    return nothing
end

mutable struct FrameLimiter
    ns_per_frame::UInt64
    next_frame_ns::UInt64
    busy_wait_threshold_ns::UInt64
    
    function FrameLimiter(frame_rate::Float64)
        ns_per_frame = round(UInt64, 1_000_000_000 / frame_rate)
        new(ns_per_frame, time_ns() + ns_per_frame, 2_000_000)
    end
end

set_limit!(::Nothing, limit::Float64) = nothing
function set_limit!(frame_limiter::FrameLimiter, limit::Float64)
    frame_limiter.ns_per_frame = round(UInt64, 1_000_000_000 / limit)
end

function get_limit(::Nothing)::Float64
    primary = GLFW.GetPrimaryMonitor()
    mode = GLFW.GetVideoMode(primary)
    return mode.refreshrate
end
function get_limit(frame_limiter::FrameLimiter)::Float64
    return Float64(1_000_000_000) / Float64(frame_limiter.ns_per_frame)
end

function before_buffer_swap!(fl::FrameLimiter)::Nothing
    while (now = time_ns()) < fl.next_frame_ns - fl.busy_wait_threshold_ns
        sleep(0.001)
    end
    
    while time_ns() < fl.next_frame_ns
        ccall(:jl_cpu_pause, Cvoid, ())
    end
    return nothing
end

function after_buffer_swap!(fl::FrameLimiter)::Nothing
    if time_ns() > fl.next_frame_ns + fl.ns_per_frame
        fl.next_frame_ns = time_ns()
    end
    fl.next_frame_ns += fl.ns_per_frame
    return nothing
end