mutable struct FrameTime <: WindowDNA
    window::Window
    gpu_times::Vector{Vector{Float64}}
    cpu_times::Vector{Float64}
    frame_times::Vector{Float64}
    insert_times::Vector{Float64}
    target_fps::Float32
    

    function FrameTime()
        rt =new(Window(),Vector{Float64}[],Vector{Float64}[],Float64[],Float64[],get_global_setting("Graphics/Display/Framerate/Max FPS"))
        on_setting_changed("Graphics/Display/Framerate/Max FPS", _update_target_framerate, [rt])
        return rt
    end
end

_Window_(gui::FrameTime)::Window = gui.window
getWindowName(gui::FrameTime) = "Frame Time"

function _update_target_framerate(value, window)
    window[1].target_fps = value
end

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

    current_dt = app._delta_time * 1000.0
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
    return nothing
end