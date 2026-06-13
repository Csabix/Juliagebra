mutable struct FrameTime <: WindowDNA
    window::Window
    gpu_times::Vector{Vector{Float64}}
    cpu_times::Vector{Float64}
    frame_times::Vector{Float64}
    insert_times::Vector{Float64}
    target_fps::Ref{Float32}
    limit_framerate::Ref{Bool}

    function FrameTime()
        primary = GLFW.GetPrimaryMonitor()
        mode = GLFW.GetVideoMode(primary)
        refresh_rate = mode.refreshrate
        return new(Window(),Vector{Float64}[],Vector{Float64}[],Float64[],Float64[],Ref(Float32(refresh_rate)),Ref(false))
    end
end

_Window_(gui::FrameTime)::Window = gui.window
getWindowName(gui::FrameTime) = "Frame Time"

function renderContent(gui::FrameTime, app::AppDNA)::Nothing
    opengl_data::OpenGLData = getOpenGL(app)
    frame_gpu_times = opengl_data._profiler.gpu_times
    passes = opengl_data._passes

    current_time = time()
    cutoff_time = current_time - 60.0
    valid_idx = findfirst(t -> t >= cutoff_time, gui.insert_times)
    
    if valid_idx !== nothing && valid_idx > 1
        deleteat!(gui.insert_times, 1:(valid_idx - 1))
        deleteat!(gui.gpu_times, 1:(valid_idx - 1))
        deleteat!(gui.cpu_times, 1:(valid_idx - 1))
        deleteat!(gui.frame_times, 1:(valid_idx - 1))
    end

    current_dt = Float64(app._shrd._deltaTime) * 1000.0
    if isempty(gui.frame_times)
        push!(gui.frame_times, current_dt)
    else
        push!(gui.frame_times, (0.9) * gui.frame_times[end] + 0.1 * current_dt)
    end
    push!(gui.frame_times)
    push!(gui.insert_times, current_time)
    current_frame_pass_times = [
        frame_gpu_times[passes.pre_draw],
        frame_gpu_times[passes.widgets],
        frame_gpu_times[passes.opaque],
        frame_gpu_times[passes.behind_opaque],
        frame_gpu_times[passes.transparent],
        frame_gpu_times[passes.post_process]
    ]
    push!(gui.gpu_times, current_frame_pass_times)
    push!(gui.cpu_times, opengl_data._profiler.cpu_times[opengl_data._cpu_stopwatch])

    ImPlot.SetNextAxisLimits(ImPlot.ImAxis_X1, -60.0, 0.0, CImGui.ImGuiCond_Always)
    if ImPlot.BeginPlot("FrameTime", "Time (seconds ago)", "Render Time (ms)")
        num_frames = length(gui.insert_times)
        x_coords = [t - current_time for t in gui.insert_times]
        labels = ("Pre-Draw", "Widgets", "Opaque", "Behind Opaque", "Transparent", "Post-Process")
        num_passes = length(labels)
        
        y_baseline = zeros(Float64, num_frames)
        y_top = zeros(Float64, num_frames)
        for p in 1:num_passes
            for f in 1:num_frames
                y_top[f] = y_baseline[f] + gui.gpu_times[f][p]
            end
            ImPlot.PlotShaded(labels[p], x_coords, y_baseline, y_top, num_frames)
            y_baseline .= y_top
        end
        ImPlot.PlotLine("Render CPU", x_coords, gui.cpu_times, num_frames)
        ImPlot.PlotLine("Frame times", x_coords, gui.frame_times, num_frames)
        target_frametime::Float64 = if app._frame_limiter !== nothing
                1000000000.0 / app._frame_limiter.ns_per_frame
            else
                1000.0/gui.target_fps[]
            end
        ImPlot.PlotLine("Target render time", [-60.0, 0.0], [target_frametime, target_frametime], 2)
        ImPlot.EndPlot()
    end

    if CImGui.Checkbox("Framerate Limit",gui.limit_framerate)
        if gui.limit_framerate[]
            app._frame_limiter = FrameLimiter(Float64(gui.target_fps[]))
        else
            app._frame_limiter = nothing
        end
    end
    if CImGui.SliderFloat("Target Framerate", gui.target_fps, 10.0, 144.0)
        set_limit!(app._frame_limiter, Float64(gui.target_fps[]))
    end

    items = ("Adaptive (-1)", "Off (0)", "On (1)")
    current_idx = app._shrd._vsync_state == -1 ? 0 : (app._shrd._vsync_state == 0 ? 1 : 2)

    if CImGui.BeginCombo("VSync Interval", items[current_idx + 1])
        for i in 0:2
            is_selected = (current_idx == i)
            if CImGui.Selectable(items[i+1], is_selected)
                new_val = i == 0 ? -1 : (i == 1 ? 0 : 1)
                app._shrd._vsync_state = new_val
                GLFW.SwapInterval(new_val) 
            end
            if is_selected
                CImGui.SetItemDefaultFocus()
            end
        end
        CImGui.EndCombo()
    end
    return nothing
end