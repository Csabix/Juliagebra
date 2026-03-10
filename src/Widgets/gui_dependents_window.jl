
# ? ---------------------------------
# ! GuiDependentsWindow
# ? ---------------------------------

mutable struct GuiDependentsWindow <: WindowDNA
    _window::Window
    _pool::Vector{GuiRendererDNA} # ? This pool is from "ImGuiData".
    
    function GuiDependentsWindow(pool::Vector{GuiRendererDNA})
        window = Window()
        new(window,pool)
    end
end

_Window_(self::GuiDependentsWindow)::Window = self._window
getWindowName(self::GuiDependentsWindow) = return "GuiDependents"

function renderContent(self::GuiDependentsWindow)
    for observer in self._pool
        if hasInstance(observer)
            render!(observer)
        end
    end
end