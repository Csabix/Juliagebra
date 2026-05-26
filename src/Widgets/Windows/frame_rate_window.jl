mutable struct FrameTime <: WindowDNA
    _window::Window
    _frame_times_s::Vector{Float64}
    _frame_times_smoothed_s::Vector{Float64}
    _target_fps::Ref{Float32}

    function FrameTime()
        new(Window(), [0.0 for i in 1:500], [0.0 for i in 1:500], Ref{Float32}(60.0))
    end
end

_Window_(self::FrameTime)::Window = self._window
getWindowName(self::FrameTime) = "Frame Time"

function ImVec4ToU32(color::CImGui.ImVec4)
    r = round(UInt32, color.x * 255)
    g = round(UInt32, color.y * 255)
    b = round(UInt32, color.z * 255)
    a = round(UInt32, color.w * 255)
    return (a << 24) | (b << 16) | (g << 8) | r
end

function DrawMultiLineGraph(window::FrameTime)
    canvas_size = CImGui.ImVec2(400, 180)
    CImGui.InvisibleButton("graph_canvas", canvas_size)
    p0 = CImGui.GetItemRectMin()
    p1 = CImGui.GetItemRectMax()
    
    draw_list = CImGui.GetWindowDrawList()
    
    CImGui.AddRectFilled(draw_list, p0, p1, ImVec4ToU32(CImGui.ImVec4(0.07, 0.07, 0.07, 1.0)))
    CImGui.AddRect(draw_list, p0, p1, ImVec4ToU32(CImGui.ImVec4(0.25, 0.25, 0.25, 1.0)))
    
    history_len = length(window._frame_times_s)
    step_x = canvas_size.x / (history_len - 1)
    
    max_time = max(
        maximum(window._frame_times_s), 
        1.0 / window._target_fps[] * 1.5, 
        0.001
    )
    
    function value_to_y(val::Float64)
        normalized_y = val / max_time
        return p1.y - (normalized_y * canvas_size.y)
    end
    
    color_target   = ImVec4ToU32(CImGui.ImVec4(0.8, 0.2, 0.2, 0.7))
    color_raw      = ImVec4ToU32(CImGui.ImVec4(0.2, 0.7, 0.2, 0.8))
    color_smoothed = ImVec4ToU32(CImGui.ImVec4(0.2, 0.5, 1.0, 1.0))
    
    for i in 1:(history_len - 1)
        x1 = p0.x + (i - 1) * step_x
        x2 = p0.x + i * step_x
        
        y1_raw = value_to_y(window._frame_times_s[i])
        y2_raw = value_to_y(window._frame_times_s[i + 1])
        CImGui.AddLine(draw_list, CImGui.ImVec2(x1, y1_raw), CImGui.ImVec2(x2, y2_raw), color_raw, 1.0)
        
        y1_smooth = value_to_y(window._frame_times_smoothed_s[i])
        y2_smooth = value_to_y(window._frame_times_smoothed_s[i + 1])
        CImGui.AddLine(draw_list, CImGui.ImVec2(x1, y1_smooth), CImGui.ImVec2(x2, y2_smooth), color_smoothed, 2.0)

        y_target = value_to_y(1.0 / window._target_fps[])
        CImGui.AddLine(draw_list, CImGui.ImVec2(x1, y_target), CImGui.ImVec2(x2, y_target), color_target, 1.5)
    end
end

function renderContent(self::FrameTime, app::AppDNA)
    current_dt = Float64(app._shrd._deltaTime)
    
    popfirst!(self._frame_times_s)
    push!(self._frame_times_s, current_dt)
    
    tail_span = min(10, length(self._frame_times_s))
    recent_frames = view(self._frame_times_s, (length(self._frame_times_s) - tail_span + 1):length(self._frame_times_s))
    avg_dt = sum(recent_frames) / tail_span
    
    popfirst!(self._frame_times_smoothed_s)
    push!(self._frame_times_smoothed_s, avg_dt)
    
    DrawMultiLineGraph(self)

    CImGui.Spacing()
    CImGui.Text("Graph Legend:")
    CImGui.SameLine()
    CImGui.TextColored(CImGui.ImVec4(0.8, 0.2, 0.2, 1.0), "■ Target")
    CImGui.SameLine()
    CImGui.TextColored(CImGui.ImVec4(0.2, 0.7, 0.2, 1.0), "■ Raw")
    CImGui.SameLine()
    CImGui.TextColored(CImGui.ImVec4(0.2, 0.5, 1.0, 1.0), "■ Smoothed")
    
    CImGui.Separator()
    
    target_ms = 1000.0 / self._target_fps[]
    valid_times = filter(t -> t > 0.0, self._frame_times_s)
    min_ms = isempty(valid_times) ? 0.0 : minimum(valid_times) * 1000.0
    max_ms = isempty(valid_times) ? 0.0 : maximum(valid_times) * 1000.0
    
    CImGui.Text("Target Frame Time: $(round(target_ms, digits=3)) ms")
    CImGui.Text("Min Frame Time:    $(round(min_ms, digits=3)) ms")
    CImGui.Text("Max Frame Time:    $(round(max_ms, digits=3)) ms")
    
    CImGui.Separator()

    if CImGui.SliderFloat("Target Framerate", self._target_fps, 10.0, 120.0)
        set_limit(app._frame_limiter, Float64(self._target_fps[]))
    end

    items = ["Adaptive (-1)", "Off (0)", "On (1)"]
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

    CImGui.Text("Frame Limiter:")
    CImGui.SameLine()
    if CImGui.Button("None")
        app._frame_limiter = nothing
    end
    CImGui.SameLine()
    if CImGui.Button("Limiter A")
        app._frame_limiter = FrameLimiterA(Float64(self._target_fps[]))
    end
    CImGui.SameLine()
    if CImGui.Button("Limiter B")
        app._frame_limiter = FrameLimiterB(Float64(self._target_fps[]))
    end
    CImGui.SameLine()
    if CImGui.Button("Limiter C")
        app._frame_limiter = FrameLimiterC(Float64(self._target_fps[]))
    end
end