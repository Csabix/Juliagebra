
mutable struct PointsWindow <: WindowDNA
    _window::Window
    _graph::DependentGraphDNA

    PointsWindow(graph::DependentGraphDNA) = new(Window(), graph)
end

_Window_(self::PointsWindow)::Window = self._window
getWindowName(self::PointsWindow) = "Points"

function renderContent(self::PointsWindow)
    col_flags = CImGui.ImGuiTableColumnFlags_WidthFixed
    if !CImGui.BeginTable("points_tbl", 6,
            CImGui.ImGuiTableFlags_Borders | CImGui.ImGuiTableFlags_RowBg |
            CImGui.ImGuiTableFlags_ScrollY)
        return
    end

    CImGui.TableSetupScrollFreeze(0, 1)
    CImGui.TableSetupColumn("ID",    col_flags, 28.0)
    CImGui.TableSetupColumn("X")
    CImGui.TableSetupColumn("Y")
    CImGui.TableSetupColumn("Z")
    CImGui.TableSetupColumn("Color", col_flags, 100.0)
    CImGui.TableSetupColumn("Style", col_flags, 60.0)
    CImGui.TableHeadersRow()

    for node in getNodes(self._graph)
        node isa PointDependent || continue

        id    = getGraphID(node)
        coord = node._coord
        x_ref = Ref(Cdouble(coord.x))
        y_ref = Ref(Cdouble(coord.y))
        z_ref = Ref(Cdouble(coord.z))

        CImGui.TableNextRow()

        CImGui.TableNextColumn()
        CImGui.Text("$id")

        CImGui.TableNextColumn()
        if CImGui.InputDouble("##x$id", x_ref, 0.0, 0.0, "%.4f")
            set(node, x_ref[], coord.y, coord.z)
        end

        CImGui.TableNextColumn()
        if CImGui.InputDouble("##y$id", y_ref, 0.0, 0.0, "%.4f")
            set(node, coord.x, y_ref[], coord.z)
        end

        CImGui.TableNextColumn()
        if CImGui.InputDouble("##z$id", z_ref, 0.0, 0.0, "%.4f")
            set(node, coord.x, coord.y, z_ref[])
        end

        CImGui.TableNextColumn()
        new_color = color_edit3(node._color, "##pcol$id")
        if new_color !== nothing
            node._color = new_color
            afterNodeEval(node)
        end

        CImGui.TableNextColumn()
        is_none = node._point_type == POINT_NONE
        if CImGui.RadioButton("·##$id", is_none)
            node._point_type = POINT_NONE
            afterNodeEval(node)
        end
        CImGui.SameLine()
        if CImGui.RadioButton("+##$id", !is_none)
            node._point_type = POINT_PLUS
            afterNodeEval(node)
        end
    end

    CImGui.EndTable()
end
