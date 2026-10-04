const _PASS_LABELS = ("Pre-Draw", "Widgets", "Opaque", "Behind Opaque", "Transparent", "Post-Process")

mutable struct FrameTime <: WindowDNA
    window::Window
    gpu_times::Vector{NTuple{6,Float64}}
    cpu_times::Vector{Float64}
    frame_times::Vector{Float64}
    insert_times::Vector{Float64}
    alloc_counts::Vector{Float64}
    alloc_kbytes::Vector{Float64}
    gc_incremental::Vector{Tuple{Float64,Float64}} # (timestamp, GC time in ms)
    gc_full::Vector{Tuple{Float64,Float64}} # (timestamp, GC time in ms)
    target_fps::Base.RefValue{Float32}
    limit_framerate::Base.RefValue{Bool}

    # Reused buffers
    x_buf::Vector{Float64}
    y_baseline_buf::Vector{Float64}
    y_top_buf::Vector{Float64}
    target_x::Vector{Float64}
    target_y::Vector{Float64}
    gc_x_buf::Vector{Float64}
    gc_y_buf::Vector{Float64}

    function FrameTime()
        primary = GLFW.GetPrimaryMonitor()
        mode = GLFW.GetVideoMode(primary)
        refresh_rate = mode.refreshrate
        return new(Window(),NTuple{6,Float64}[],Float64[],Float64[],Float64[],Float64[],Float64[],
                   Tuple{Float64,Float64}[],Tuple{Float64,Float64}[],Ref(Float32(refresh_rate)),Ref(false),
                   Float64[],Float64[],Float64[],[-60.0, 0.0],[0.0, 0.0],Float64[],Float64[])
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
        deleteat!(gui.alloc_counts, 1:(valid_idx - 1))
        deleteat!(gui.alloc_kbytes, 1:(valid_idx - 1))
    end
    _trim_gc!(gui.gc_incremental, cutoff_time)
    _trim_gc!(gui.gc_full, cutoff_time)
    if app._frame_gc_count > 0
        sample = (current_time, app._frame_gc_time_ns / 1.0e6)
        push!(app._frame_gc_full > 0 ? gui.gc_full : gui.gc_incremental, sample)
    end

    current_dt = app._delta_time * 1000.0
    if isempty(gui.frame_times)
        push!(gui.frame_times, current_dt)
    else
        push!(gui.frame_times, (0.9) * gui.frame_times[end] + 0.1 * current_dt)
    end
    push!(gui.insert_times, current_time)
    push!(gui.gpu_times, (
        frame_gpu_times[passes.pre_draw],
        frame_gpu_times[passes.widgets],
        frame_gpu_times[passes.opaque],
        frame_gpu_times[passes.behind_opaque],
        frame_gpu_times[passes.transparent],
        frame_gpu_times[passes.post_process]
    ))
    push!(gui.cpu_times, opengl_data._profiler.cpu_times[opengl_data._cpu_stopwatch])
    push!(gui.alloc_counts, Float64(app._frame_alloc_count))
    push!(gui.alloc_kbytes, app._frame_alloc_bytes / 1024.0)

    num_frames = length(gui.insert_times)
    x_coords = Base.resize!(gui.x_buf, num_frames)
    @inbounds for f in 1:num_frames
        x_coords[f] = gui.insert_times[f] - current_time
    end

    ImPlot.SetNextAxisLimits(ImPlot.ImAxis_X1, -60.0, 0.0, CImGui.ImGuiCond_Always)
    if ImPlot.BeginPlot("FrameTime", "Time (seconds ago)", "Render Time (ms)")
        y_baseline = fill!(Base.resize!(gui.y_baseline_buf, num_frames), 0.0)
        y_top = Base.resize!(gui.y_top_buf, num_frames)
        for p in 1:length(_PASS_LABELS)
            @inbounds for f in 1:num_frames
                y_top[f] = y_baseline[f] + gui.gpu_times[f][p]
            end
            ImPlot.PlotShaded(_PASS_LABELS[p], x_coords, y_baseline, y_top, num_frames)
            copyto!(y_baseline, y_top)
        end
        ImPlot.PlotLine("Render CPU", x_coords, gui.cpu_times, num_frames)
        ImPlot.PlotLine("Frame times", x_coords, gui.frame_times, num_frames)
        target_frametime::Float64 = if app._frame_limiter !== nothing
            frame_limiter::FrameLimiter = app._frame_limiter
                1000000000.0 / frame_limiter.ns_per_frame
            else
                1000.0/gui.target_fps[]
            end
        fill!(gui.target_y, target_frametime)
        ImPlot.PlotLine("Target render time", gui.target_x, gui.target_y, 2)
        _plot_gc_points(gui, "GC incremental", gui.gc_incremental, current_time,
                        ImPlot.ImPlotMarker_Cross, CImGui.ImVec4(0.25, 0.55, 1.0, 1.0))
        _plot_gc_points(gui, "GC full", gui.gc_full, current_time,
                        ImPlot.ImPlotMarker_Cross, CImGui.ImVec4(1.0, 0.2, 0.2, 1.0))
        ImPlot.EndPlot()
    end

    ImPlot.SetNextAxisLimits(ImPlot.ImAxis_X1, -60.0, 0.0, CImGui.ImGuiCond_Always)
    if ImPlot.BeginPlot("Allocations", "Time (seconds ago)", "Allocations per frame")
        ImPlot.PlotLine("Allocation count", x_coords, gui.alloc_counts, num_frames)
        ImPlot.PlotLine("Allocated KiB", x_coords, gui.alloc_kbytes, num_frames)
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
    current_idx = app._vsync_state == -1 ? 0 : (app._vsync_state == 0 ? 1 : 2)

    if CImGui.BeginCombo("VSync Interval", items[current_idx + 1])
        for i in 0:2
            is_selected = (current_idx == i)
            if CImGui.Selectable(items[i+1], is_selected)
                new_val = i == 0 ? -1 : (i == 1 ? 0 : 1)
                app._vsync_state = new_val
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

function _trim_gc!(samples::Vector{Tuple{Float64,Float64}}, cutoff_time::Float64)::Nothing
    idx = findfirst(p -> p[1] >= cutoff_time, samples)
    n = idx === nothing ? length(samples) : idx - 1
    n > 0 && deleteat!(samples, 1:n)
    return nothing
end

function _plot_gc_points(gui::FrameTime, label::String, samples::Vector{Tuple{Float64,Float64}},
                         current_time::Float64, marker, color)::Nothing
    n = length(samples)
    n == 0 && return nothing
    xs = Base.resize!(gui.gc_x_buf, n)
    ys = Base.resize!(gui.gc_y_buf, n)
    @inbounds for i in 1:n
        xs[i] = samples[i][1] - current_time
        ys[i] = samples[i][2]
    end
    ImPlot.SetNextMarkerStyle(marker, 5.0, color, 1.5, color)
    ImPlot.PlotScatter(label, xs, ys, n)
    return nothing
end
