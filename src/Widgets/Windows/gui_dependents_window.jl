
# ? ---------------------------------
# ! GuiDependentsWindow
# ? ---------------------------------

@kwdef mutable struct GuiDependentsWindow <: WindowDNA
    window::Window = Window()
    graph::GeometryPlotGraph
    GuiDependentsWindow(graph::GeometryPlotGraph) = new(Window(), graph)
end

_Window_(self::GuiDependentsWindow)::Window = self.window
getWindowName(self::GuiDependentsWindow) = return "GuiDependents"

function renderContent(window::GuiDependentsWindow, app::AppDNA)
    elements::Vector{Any} = window.graph.elements
    for index in eachindex(elements)
        CImGui.PushID(index)
        e, invalidate = render_node_gui(elements[index])
        elements[index] = e
        if invalidate
            invalidate!(window.graph, NodeHandle(index)) 
        end
        CImGui.PopID()
    end
end
