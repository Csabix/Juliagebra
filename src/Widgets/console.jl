const _colors::SVector{4, UInt32} = SVector{4, UInt32}(
    CImGui.IM_COL32(255,255,255,255), # White
    CImGui.IM_COL32( 40, 89,219,255), # Blue
    CImGui.IM_COL32(226,132,  9,255), # Orange
    CImGui.IM_COL32(255,  0,  0,255)  # Red
)

mutable struct Console <: WindowDNA
    _window::Window
    _bottom_last_frame::Bool
    
    function Console()
        clear_logs()
        window = Window()

        new(window,true)
    end
end

_Window_(self::Console)::Window = return self._window
getWindowName(self::Console) = return "Console"

function renderContent(self::Console)
    if CImGui.Button("Clear")
        empty!(_messages)
    end

    if CImGui.BeginMenu("Filters")
        CImGui.Checkbox("Log", pointer(_filters, 1));
        CImGui.Checkbox("Info", pointer(_filters, 2));
        CImGui.Checkbox("Warning", pointer(_filters, 3));
        CImGui.Checkbox("Error", pointer(_filters, 4));
        CImGui.EndMenu()
    end

    CImGui.BeginChild("messages", (0, 0), false, CImGui.ImGuiWindowFlags_HorizontalScrollbar);
    for msg in _messages
        CImGui.PushStyleColor(CImGui.ImGuiCol_Text, _colors[msg.type])
        CImGui.Text(msg.text)
        CImGui.PopStyleColor();
    end

    self._bottom_last_frame = CImGui.GetScrollY() == CImGui.GetScrollMaxY()
    if self._bottom_last_frame
        CImGui.SetScrollHereY(1.0);
    end
    CImGui.EndChild();
end