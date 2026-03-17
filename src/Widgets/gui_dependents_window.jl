
# ? ---------------------------------
# ! GuiDependentsWindow
# ? ---------------------------------

mutable struct GuiDependentsWindow <: WindowDNA
    _window::Window
    function GuiDependentsWindow()
        new(Window())
    end
end

_Window_(self::GuiDependentsWindow)::Window = self._window
getWindowName(self::GuiDependentsWindow) = return "GuiDependents"

function renderContent(self::GuiDependentsWindow, imgui::ImGuiDNA)
    pool::Vector{GuiRendererDNA} = imgui._pool
    
    for idx in eachindex(pool)
        observer = pool[idx]
        
        if hasInstance(observer)    
            CImGui.PushID(idx)
            render!(observer)
            CImGui.PopID()
        end
    end
end