mutable struct Widget
    _isVisible::Bool
    function Widget()
        isVisible = false
        new(isVisible)
    end
end

_Widget_(self::WidgetDNA)::Widget = error("Missing \"_Widget_\" func for type of \"$(typeof(self))\"!")
render(self::WidgetDNA) = error("Missing \"render\" func for type of \"$(typeof(self))\"!")

function toggle!(self::WidgetDNA) 
    widget = _Widget_(self)
    widget._isVisible = !widget._isVisible
end

setVisible(self::WidgetDNA,isVisible::Bool) = _Widget_(self)._isVisible = isVisible
isVisible(self::WidgetDNA) = _Widget_(self)._isVisible