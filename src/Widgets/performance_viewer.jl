mutable struct PerformanceWindow <: WindowDNA
    _window::Window

    function PerformanceWindow()
        window = Window()
        new(window)
    end
end

_Window_(self::PerformanceWindow)::Window = self._window
getWindowName(self::PerformanceWindow) = return "Timings"

function renderContent(self::PerformanceWindow)
    if _perf_layers.childs !== nothing
        for layer in _perf_layers.childs
            ui_render_perf_tree(layer)
        end
    end
end

function ui_render_perf_tree(layer::PerfLayer)
    if CImGui.TreeNodeEx(layer.name, CImGui.ImGuiTreeNodeFlags_OpenOnArrow)
        _display_layer(layer)
        if layer.childs !== nothing
            for child in layer.childs
                ui_render_perf_tree(child)
            end
        end
        CImGui.TreePop()
    end
end

function _display_layer(layer::PerfLayer)
    if layer.index != 0
        collect_data = get_collect_data(layer)
        if CImGui.Button(collect_data ? "Deactivate" : "Activate")
            set_collect_data(layer,!collect_data)
        end
    end

    cpu_times = get_cpu_times(layer)
    if cpu_times !== nothing
        total = zero(eltype(cpu_times))
        count = 0
        for time in cpu_times
            total += time
            count += 1
        end

        CImGui.Text("Avg. CPU time(ms): $(total / 1000000.0 / count)")
    end

    gpu_times = get_gpu_times(layer)
    if gpu_times !== nothing
        total = zero(eltype(gpu_times))
        count = 0
        for time in gpu_times
            total += time
            count += 1
        end
        CImGui.Text("Avg. GPU time(ms): $(total / 1000000.0 / count)")
    end
end