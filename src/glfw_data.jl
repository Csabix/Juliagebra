mutable struct GLFWData

    _shrd::SharedData
    _window::GLFW.Window

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

        new(shrd,window)
    end
end

destroy!(glfw::GLFWData) = GLFW.DestroyWindow(glfw._window)
disable_mouse(glfw::GLFWData) = GLFW.SetInputMode(glfw._window, GLFW.CURSOR, GLFW.CURSOR_DISABLED);
enable_mouse(glfw::GLFWData) = GLFW.SetInputMode(glfw._window, GLFW.CURSOR, GLFW.CURSOR_NORMAL);

abstract type FrameLimiter end

mutable struct FrameLimiterA <: FrameLimiter
    seconds_per_frame::Float64
    next_frame::Float64
    frame_rate_limit::Float64
    FrameLimiterA(frame_rate::Float64) = new(1.0/frame_rate, time() + 1.0/frame_rate, frame_rate)
end

function before_buffer_swap!(frame_limiter::FrameLimiterA)::Nothing
    sleep_time = max(frame_limiter.next_frame - time() - 0.003, 0.0)
    if sleep_time > 0.001
        sleep(sleep_time)
    end
    while frame_limiter.next_frame - time() > 0.001
        yield()
    end
    return nothing
end

function after_buffer_swap!(frame_limiter::FrameLimiterA)::Nothing
    frame_limiter.next_frame = time() + frame_limiter.seconds_per_frame
    return nothing
end

set_limit(::Nothing, limit::Float64) = nothing

function set_limit(frame_limiter::FrameLimiterA, limit::Float64)
    frame_limiter.frame_rate_limit = limit
    frame_limiter.seconds_per_frame = 1.0 / limit
end

mutable struct FrameLimiterB <: FrameLimiter
    ns_per_frame::UInt64
    next_frame_ns::UInt64
    busy_wait_threshold_ns::UInt64
    spin_count::UInt64

    function FrameLimiterB(frame_rate::Float64)
        ns_per_frame = round(UInt64, 1_000_000_000 / frame_rate)
        new(ns_per_frame, time_ns() + ns_per_frame, 2_000_000,0)
    end
end

function set_limit(frame_limiter::FrameLimiterB, limit::Float64)
    frame_limiter.ns_per_frame = round(UInt64, 1_000_000_000 / limit)
end

function before_buffer_swap!(fl::FrameLimiterB)::Nothing
    while (now = time_ns()) < fl.next_frame_ns - fl.busy_wait_threshold_ns
        sleep(0.001)
    end
    
    while time_ns() < fl.next_frame_ns
        fl.spin_count += 1
        #ccall(:jl_cpu_pause, Cvoid, ())
    end
    return nothing
end

function after_buffer_swap!(fl::FrameLimiterB)::Nothing
    #fl.next_frame_ns = time_ns() + fl.ns_per_frame
    fl.next_frame_ns += fl.ns_per_frame
    
    if time_ns() > fl.next_frame_ns + fl.ns_per_frame
        fl.next_frame_ns = time_ns() + fl.ns_per_frame
    end
    println(fl.spin_count)
    fl.spin_count = 0
    return nothing
end

mutable struct FrameLimiterC <: FrameLimiter
    ns_per_frame::UInt64
    next_frame_ns::UInt64
    busy_wait_threshold_ns::UInt64
    spin_count::UInt64

    function FrameLimiterC(frame_rate::Float64)
        ns_per_frame = round(UInt64, 1_000_000_000 / frame_rate)
        new(ns_per_frame, time_ns() + ns_per_frame, 2_000_000,0)
    end
end

function set_limit(frame_limiter::FrameLimiterC, limit::Float64)
    frame_limiter.ns_per_frame = round(UInt64, 1_000_000_000 / limit)
end

function before_buffer_swap!(fl::FrameLimiterC)::Nothing
    while (now = time_ns()) < fl.next_frame_ns - fl.busy_wait_threshold_ns
        sleep(0.001)
    end

    #time = time_ns()
    #if time < fl.next_frame_ns
    #    fl.busy_wait_threshold_ns -= (fl.next_frame_ns - time) / 10
    #else
    #    fl.busy_wait_threshold_ns += (fl.next_frame_ns - time) / 10
    #end
    
    while time_ns() < fl.next_frame_ns
        fl.spin_count += 1
        #ccall(:jl_cpu_pause, Cvoid, ())
    end
    return nothing
end

function after_buffer_swap!(fl::FrameLimiterC)::Nothing
    #fl.next_frame_ns += fl.ns_per_frame
    #
    #if time_ns() > fl.next_frame_ns + fl.ns_per_frame
    #    fl.next_frame_ns = time_ns() + fl.ns_per_frame
    #end
    fl.next_frame_ns = time_ns() + UInt64(floor(fl.ns_per_frame * 0.9))
    println(fl.spin_count)
    fl.spin_count = 0
    return nothing
end