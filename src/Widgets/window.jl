
mutable struct Window <: ImGuiWidgetDNA 
    _widget::ImGuiWidget

    function Window()
        widget = ImGuiWidget()

        new(widget)
    end
end

_ImGuiWidget_(self::WindowDNA)::ImGuiWidget = return _Window_(self)._widget
_Window_(self::WindowDNA)::Window = error("Missing \"_Window_\" func for type of \"$(typeof(self))\"!")

getWindowName(self::WindowDNA) = error("Missing \"getWindowName\" func for type of \"$(typeof(self))\"!")
renderContent(self::WindowDNA) = error("Missing \"renderContent\" func for type of \"$(typeof(self))\"!")

function render(self::WindowDNA)
    if (isVisible(self))
        isVisible_Ref = Ref(isVisible(self))

        CImGui.Begin(getWindowName(self),isVisible_Ref)
        
        renderContent(self)

        CImGui.End()

        setVisible(self,isVisible_Ref[])
    end
end