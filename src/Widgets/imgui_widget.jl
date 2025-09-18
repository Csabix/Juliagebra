
mutable struct ImGuiWidget <: WidgetDNA
    _widget::Widget

    function ImGuiWidget()
        widget = Widget()
        new(widget)
    end
end

_Widget_(self::ImGuiWidgetDNA)::Widget = return _ImGuiWidget_(self)._widget
_ImGuiWidget_(self::ImGuiWidgetDNA)::ImGuiWidget = error("Missing \"_ImGuiWidget_\" func for type of \"$(typeof(self))\"!")