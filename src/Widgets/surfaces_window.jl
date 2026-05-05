
mutable struct SurfacesWindow <: WindowDNA
    _window::Window
    _graph::DependentGraphDNA
    _renderer::TriangleRenderer

    SurfacesWindow(graph::DependentGraphDNA, renderer::TriangleRenderer) = new(Window(), graph, renderer)
end

_Window_(self::SurfacesWindow)::Window = self._window
getWindowName(self::SurfacesWindow) = "Surfaces"

function set_color(r::TriangleRenderer,d::ParametricSurfaceDependent)
    ref = getObserver(d)._refs[getObserverID(d)]
    update_color!(r,ref,d._color)
end
function set_color(r::TriangleRenderer,d::TriangleClusterDependent)
    ref = getObserver(d)._refs[getObserverID(d)]
    update_color!(r,ref,d._color)
end

function renderContent(self::SurfacesWindow)
    col_flags = CImGui.ImGuiTableColumnFlags_WidthFixed
    if !CImGui.BeginTable("surfaces_tbl", 2,
            CImGui.ImGuiTableFlags_Borders | CImGui.ImGuiTableFlags_RowBg |
            CImGui.ImGuiTableFlags_ScrollY)
        return
    end

    CImGui.TableSetupScrollFreeze(0, 1)
    CImGui.TableSetupColumn("ID",          col_flags, 28.0)
    CImGui.TableSetupColumn("Color")
    CImGui.TableHeadersRow()

    for node in getNodes(self._graph)
        if !(node isa ParametricSurfaceDependent || node isa TriangleClusterDependent)
            continue
        end

        id = getGraphID(node)
        CImGui.TableNextRow()

        CImGui.TableNextColumn()
        CImGui.Text("$id")

        CImGui.TableNextColumn()
        new_color = color_edit4(node._color, "##scol$id")
        if new_color !== nothing
            node._color = new_color
            set_color(self._renderer,node)
        end
    end

    CImGui.EndTable()
end
