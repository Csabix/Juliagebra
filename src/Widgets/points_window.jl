
mutable struct PointsWindow <: WindowDNA
    _window::Window
    _model::Model
    _renderer::PointRenderer

    PointsWindow(model::Model, renderer::PointRenderer) = new(Window(), model, renderer)
end

_Window_(self::PointsWindow)::Window = self._window
getWindowName(self::PointsWindow) = "Points"

get_type_name(_::PointDependent)::String = "Point"
get_type_name(_::PointSetDependent)::String = "PointSet"
get_type_name(_::PointSequenceDependent)::String = "PointSequence"

function set_color(r::PointRenderer,d::PointDependent,c::UInt32)
    d._color = c
    ref = getObserver(d)._refs[getObserverID(d)]
    update_colors!(r,ref,c)
end
function set_color(r::PointRenderer,d::PointSetDependent,c::UInt32)
    d._color = c
    ref = getObserver(d)._refs[getObserverID(d)]
    update_colors!(r,ref,length(d._coords),cycle([c]))
end
function set_color(r::PointRenderer,d::PointSequenceDependent,c::UInt32)
    d._color = c
    ref = getObserver(d)._refs[getObserverID(d)]
    update_colors_dynamic!(r,ref,cycle([c]))
end

function set_size(r::PointRenderer,d::PointDependent,s::UInt8)
    d._size = s
    ref = getObserver(d)._refs[getObserverID(d)]
    update_sizes!(r,ref,s)
end
function set_size(r::PointRenderer,d::PointSetDependent,s::UInt8)
    d._size = s
    ref = getObserver(d)._refs[getObserverID(d)]
    update_sizes!(r,ref,length(d._coords),cycle([s]))
end
function set_size(r::PointRenderer,d::PointSequenceDependent,s::UInt8)
    d._size = s
    ref = getObserver(d)._refs[getObserverID(d)]
    update_sizes_dynamic!(r,ref,cycle([s]))
end

function set_style(r::PointRenderer,d::PointDependent,s::UInt8)
    d._style = s
    ref = getObserver(d)._refs[getObserverID(d)]
    update_styles!(r,ref,s)
end
function set_style(r::PointRenderer,d::PointSetDependent,s::UInt8)
    d._style = s
    ref = getObserver(d)._refs[getObserverID(d)]
    update_styles!(r,ref,length(d._coords),cycle([s]))
end
function set_style(r::PointRenderer,d::PointSequenceDependent,s::UInt8)
    d._style = s
    ref = getObserver(d)._refs[getObserverID(d)]
    update_styles_dynamic!(r,ref,cycle([s]))
end

const _POINT_STYLE_VALUES = [POINT_NONE, POINT_PLUS]
const _POINT_STYLE_LABELS = [".", "+"]
function renderContent(self::PointsWindow, app::AppDNA)
    col_flags = CImGui.ImGuiTableColumnFlags_WidthFixed
    
    if !CImGui.BeginTable("points_tbl", 8,
            CImGui.ImGuiTableFlags_Borders |
            CImGui.ImGuiTableFlags_RowBg   |
            CImGui.ImGuiTableFlags_ScrollY)
        return
    end

    CImGui.TableSetupScrollFreeze(0, 1)
    CImGui.TableSetupColumn("ID",    col_flags, 28.0)
    CImGui.TableSetupColumn("Type",  col_flags, 100.0)
    CImGui.TableSetupColumn("X")
    CImGui.TableSetupColumn("Y")
    CImGui.TableSetupColumn("Z")
    CImGui.TableSetupColumn("Color", col_flags, 100.0)
    CImGui.TableSetupColumn("Style", col_flags, 80.0)
    CImGui.TableSetupColumn("Size",  col_flags, 80.0)
    CImGui.TableHeadersRow()

    for node in getNodes(self._model._graph)
        if !(node isa PointDependent || node isa PointSetDependent || node isa PointSequenceDependent)
            continue
        end

        id = getGraphID(node)

        CImGui.TableNextRow()

        CImGui.TableNextColumn()
        CImGui.Text("$id")

        CImGui.TableNextColumn()
        CImGui.Text(get_type_name(node))

        if node isa PointDependent
            coord = node._coord
            x_ref = Ref(Cdouble(coord.x))
            y_ref = Ref(Cdouble(coord.y))
            z_ref = Ref(Cdouble(coord.z))

            position_changed = false

            CImGui.TableNextColumn()
            CImGui.PushItemWidth(-1)
            if CImGui.InputDouble("##x$id", x_ref, 0.0, 0.0, "%.4f")
                node._coord = Vec3D(
                    x_ref[],
                    coord[2],
                    coord[3]
                )
                schedule(self._model,node)
                position_changed = true
            end

            CImGui.TableNextColumn()
            CImGui.PushItemWidth(-1)
            if CImGui.InputDouble("##y$id", y_ref, 0.0, 0.0, "%.4f")
                node._coord = Vec3D(
                    coord[1],
                    y_ref[],
                    coord[3]
                )
                schedule(self._model,node)
                position_changed = true
            end

            CImGui.TableNextColumn()
            CImGui.PushItemWidth(-1)
            if CImGui.InputDouble("##z$id", z_ref, 0.0, 0.0, "%.4f")
                node._coord = Vec3D(
                    coord[1],
                    coord[2],
                    z_ref[]
                )
                schedule(self._model,node)
                position_changed = true
            end

            if (position_changed)
                update_position!(app, node)
            end
        else
            CImGui.TableNextColumn()
            CImGui.PushItemWidth(-1)
            CImGui.Text("---")
            CImGui.TableNextColumn()
            CImGui.PushItemWidth(-1)
            CImGui.Text("---")
            CImGui.TableNextColumn()
            CImGui.PushItemWidth(-1)
            CImGui.Text("---")
        end

        CImGui.TableNextColumn()
        new_color = color_edit3(node._color, "##pcol$id")
        if new_color !== nothing
            set_color(self._renderer, node, new_color)
        end

        CImGui.TableNextColumn()
        CImGui.PushItemWidth(-1)
        cur_idx = something(findfirst(==(node._style), _POINT_STYLE_VALUES), 1) - 1
        style_ref = Ref(Cint(cur_idx))
        if CImGui.Combo("##pst$id", style_ref, _POINT_STYLE_LABELS, length(_POINT_STYLE_LABELS))
            set_style(self._renderer, node, _POINT_STYLE_VALUES[style_ref[] + 1])
        end
        CImGui.PopItemWidth()

        CImGui.TableNextColumn()
        size_ref = Ref(Cint(node._size))
        if CImGui.SliderInt("##psz$id", size_ref, 0, 255)
            set_size(self._renderer, node, UInt8(size_ref[]))
        end
    end

    CImGui.EndTable()
end
