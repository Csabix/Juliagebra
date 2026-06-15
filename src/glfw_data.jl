mutable struct GLFWData
    _shrd::SharedData
    _window::GLFW.Window
    _scale::Float32

    function GLFWData(shrd::SharedData)
        GLFW.WindowHint(GLFW.DOUBLEBUFFER , 1);
        GLFW.WindowHint(GLFW.DEPTH_BITS, 24);
        GLFW.WindowHint(GLFW.STENCIL_BITS, 8);

        GLFW.WindowHint(GLFW.CONTEXT_VERSION_MAJOR, 4)
        GLFW.WindowHint(GLFW.CONTEXT_VERSION_MINOR, 6)
        GLFW.WindowHint(GLFW.OPENGL_PROFILE, GLFW.OPENGL_CORE_PROFILE);
        GLFW.WindowHint(GLFW.OPENGL_DEBUG_CONTEXT, true)
        
        window = GLFW.CreateWindow(shrd._width,shrd._height,shrd._name)

        if window == C_NULL
            error("GLFW window creation failed.")
        end
        
        GLFW.MakeContextCurrent(window)
        GLFW.SwapInterval(1)
        shrd._vsync_state = 1

        (x,_) = GLFW.GetWindowContentScale(window)

        new(shrd,window,x)
    end
end

destroy!(glfw::GLFWData) = GLFW.DestroyWindow(glfw._window)
disable_mouse(glfw::GLFWData) = GLFW.SetInputMode(glfw._window, GLFW.CURSOR, GLFW.CURSOR_DISABLED);
enable_mouse(glfw::GLFWData) = GLFW.SetInputMode(glfw._window, GLFW.CURSOR, GLFW.CURSOR_NORMAL);

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