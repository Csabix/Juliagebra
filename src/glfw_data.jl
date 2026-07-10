mutable struct GLFWData
    name::String
    _window::GLFW.Window
    width::Int32
    height::Int32
    s_width::Int32
    s_height::Int32
    scale::Float32

    function GLFWData(name::String,inital_width::Int32,inital_height::Int32)
        return new(name,GLFW.Window(C_NULL),0,0,inital_width,inital_height,0.0f0)
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

    button_press::Dict{Cint,Vector{Tuple{UInt8,Function}}}
    button_release::Dict{Cint,Vector{Tuple{UInt8,Function}}}
    mouse_press::Dict{Cint,Vector{Tuple{UInt8,Function}}}
    mouse_release::Dict{Cint,Vector{Tuple{UInt8,Function}}}

    handle_map::Vector{Tuple{UInt8,Cint,UInt8,Function}}

    function Inputs(window::GLFWData)
        new(
            SVector{8}([Vector{Tuple{UInt8,Function}}() for _ in 1:8]), 
            -1.0, 
            -1.0, 
            window,
            Dict{Cint, Vector{Tuple{UInt8,Function}}}(),
            Dict{Cint, Vector{Tuple{UInt8,Function}}}(),
            Dict{Cint, Vector{Tuple{UInt8,Function}}}(),
            Dict{Cint, Vector{Tuple{UInt8,Function}}}(),
            Vector{Tuple{UInt8,Cint,UInt8,Function}}()
        )
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
    return nothing
end

is_open(window::GLFWData) = return window._window.handle != C_NULL

function deinit!(w::GLFWData)
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

swap_buffers(w::GLFWData)::Nothing = GLFW.SwapBuffers(w._window)
poll_events(::GLFWData)::Nothing = GLFW.PollEvents()

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
    inputs.last_x = NaN64
    inputs.last_y = NaN64
    GLFW.SetInputMode(inputs.window._window, GLFW.CURSOR, GLFW.CURSOR_DISABLED);
end
function enable_mouse(inputs::Inputs)
    inputs.last_x = NaN64
    inputs.last_y = NaN64
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
        isnan(inputs.last_x) ? 0.0 : xpos - inputs.last_x,isnan(inputs.last_y) ? 0.0 : ypos - inputs.last_y,
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