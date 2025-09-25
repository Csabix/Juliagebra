
mutable struct GuiDependentsWindow <: WindowDNA
    _window::Window
    _guiRenderers::Dict{<:DataType,Vector{<:GuiRendererDNA}}
end

function GuiDependentsWindow()
        window = Window()
        guiDependents = Dict{DataType,Vector{<:GuiRendererDNA}}()

        GuiDependentsWindow(window,guiDependents)
end

_Window_(self::GuiDependentsWindow)::Window = self._window
getWindowName(self::GuiDependentsWindow) = return "GuiDependents"

function renderContent(self::GuiDependentsWindow)
    for (_,guiRendererVec) in self._guiRenderers
        for guiRenderer in guiRendererVec
            render!(guiRenderer)
        end
    end
end