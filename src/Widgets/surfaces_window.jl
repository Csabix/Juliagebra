
mutable struct SurfacesWindow <: WindowDNA
    _window::Window
    _graph::DependentGraphDNA

    SurfacesWindow(graph::DependentGraphDNA) = new(Window(), graph)
end

_Window_(self::SurfacesWindow)::Window = self._window
getWindowName(self::SurfacesWindow) = "Surfaces"

function renderContent(self::SurfacesWindow)
    col_flags = CImGui.ImGuiTableColumnFlags_WidthFixed
    if !CImGui.BeginTable("surfaces_tbl", 3,
            CImGui.ImGuiTableFlags_Borders | CImGui.ImGuiTableFlags_RowBg |
            CImGui.ImGuiTableFlags_ScrollY)
        return
    end

    CImGui.TableSetupScrollFreeze(0, 1)
    CImGui.TableSetupColumn("ID",          col_flags, 28.0)
    CImGui.TableSetupColumn("Color")
    CImGui.TableHeadersRow()

    for node in getNodes(self._graph)
        node isa ParametricSurfaceDependent || continue

        id = getGraphID(node)
        CImGui.TableNextRow()

        CImGui.TableNextColumn()
        CImGui.Text("$id")

        CImGui.TableNextColumn()
        new_color = color_edit4(node._color, "##scol$id")
        if new_color !== nothing
            node._color = new_color
            afterNodeEval(node)
        end
    end

    CImGui.EndTable()
end
