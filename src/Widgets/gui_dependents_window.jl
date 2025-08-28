
mutable struct GuiDependentsWindow <: WindowDNA
    _window::Window

    function GuiDependentsWindow()
        window = Window()
        
        new(window)
    end
end

_Window_(self::GuiDependentsWindow)::Window = self._window
getWindowName(self::GuiDependentsWindow) = return "GuiDependents"

function renderContent(self::GuiDependentsWindow)
    
end