
mutable struct OpenGLWidget <: WidgetDNA
    _widget::Widget

    function OpenGLWidget()
        widget = Widget()
        new(widget)
    end
end

_Widget_(self::OpenGLWidgetDNA)::Widget = _OpenGLWidget_(self)._widget
_OpenGLWidget_(self::OpenGLWidgetDNA)::OpenGLWidget = error("Missing \"_OpenGLWidget_\" func for type of \"$(typeof(self))\"!")