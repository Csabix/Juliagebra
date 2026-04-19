
mutable struct CurvesWindow <: WindowDNA
    _window::Window
    _graph::DependentGraphDNA

    CurvesWindow(graph::DependentGraphDNA) = new(Window(), graph)
end

_Window_(self::CurvesWindow)::Window = self._window
getWindowName(self::CurvesWindow) = "Curves"

function _unpack_rgb(packed::UInt32)::Vec3F
    r = Float32( packed        & 0xff) / 255.0f0
    g = Float32((packed >>  8) & 0xff) / 255.0f0
    b = Float32((packed >> 16) & 0xff) / 255.0f0
    return Vec3F(r, g, b)
end

function _pack_rgb(color::Vec3F)::UInt32
    return UInt32(round(clamp(color[1], 0f0, 1f0) * 255)) |
           (UInt32(round(clamp(color[2], 0f0, 1f0) * 255)) << 8) |
           (UInt32(round(clamp(color[3], 0f0, 1f0) * 255)) << 16)
end

function renderContent(self::CurvesWindow)
    col_flags = CImGui.ImGuiTableColumnFlags_WidthFixed
    if !CImGui.BeginTable("curves_tbl", 3,
            CImGui.ImGuiTableFlags_Borders | CImGui.ImGuiTableFlags_RowBg |
            CImGui.ImGuiTableFlags_ScrollY)
        return
    end

    CImGui.TableSetupScrollFreeze(0, 1)
    CImGui.TableSetupColumn("ID",    col_flags, 28.0)
    CImGui.TableSetupColumn("Color")
    CImGui.TableSetupColumn("Width", col_flags, 90.0)
    CImGui.TableHeadersRow()

    for node in getNodes(self._graph)
        node isa ParametricCurveDependent || continue

        id = getGraphID(node)
        CImGui.TableNextRow()

        CImGui.TableNextColumn()
        CImGui.Text("$id")

        CImGui.TableNextColumn()
        cur_color = _unpack_rgb(node._colors[1])
        new_color = color_edit3(cur_color, "##ccol$id")
        if new_color !== nothing
            node._colors[1] = _pack_rgb(new_color)
            afterNodeEval(node)
        end

        CImGui.TableNextColumn()
        w_ref = Ref(node._width)
        if CImGui.SliderFloat("##cw$id", w_ref, 1.0f0, 20.0f0)
            node._width = w_ref[]
            afterNodeEval(node)
        end
    end

    CImGui.EndTable()
end
