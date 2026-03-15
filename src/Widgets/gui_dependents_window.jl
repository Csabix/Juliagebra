
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
    for idx in eachindex(self._pool)
        observer = self._pool[idx]
        
        if hasInstance(observer)    
            CImGui.PushID(idx)
            render!(observer)
            CImGui.PopID()
        end
    end
end