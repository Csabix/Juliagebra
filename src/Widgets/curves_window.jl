
mutable struct CurvesWindow <: WindowDNA
    _window::Window
    _model::Model
    _renderer::LineRenderer

    CurvesWindow(model::Model, renderer::LineRenderer) = new(Window(), model, renderer)
end

_Window_(self::CurvesWindow)::Window = self._window
getWindowName(self::CurvesWindow) = "Curves"

const _CURVE_STYLE_LABELS = ["-", "--", ":", "~", "-.", "->", "<-"]
# values match SOLID=1..ARROW=6, ARROW_REVERSED=ARROW|(1<<7)=134 from line_renderer.jl
const _CURVE_STYLE_VALUES = UInt8[1, 2, 3, 4, 5, 6, 134]

function set_color(r::LineRenderer,d::ParametricCurveDependent)
    ref = getObserver(d)._refs[getObserverID(d)]
    update_colors!(r,ref,cycle(d._colors))
end
function set_color(r::LineRenderer,d::SegmentSequenceDependent)
    ref = getObserver(d)._refs[getObserverID(d)]
    if d._break_every >= 2
        update_colors_dynamic!(r,ref,custom_interleaver(collect(take(cycle(d._colors),length(d._values))),zero(UInt32),d._break_every))
    else
        update_colors_dynamic!(r,ref,cycle(d._colors))
    end
end

function set_style(r::LineRenderer,d::ParametricCurveDependent)
    ref = getObserver(d)._refs[getObserverID(d)]
    update_style!(r,ref,d._style)
end
function set_style(r::LineRenderer,d::SegmentSequenceDependent)
    ref = getObserver(d)._refs[getObserverID(d)]
    update_style_dynamic!(r,ref,d._style)
end

function set_size(r::LineRenderer,d::ParametricCurveDependent)
    ref = getObserver(d)._refs[getObserverID(d)]
    update_size!(r,ref,d._size)
end
function set_size(r::LineRenderer,d::SegmentSequenceDependent)
    ref = getObserver(d)._refs[getObserverID(d)]
    update_size_dynamic!(r,ref,d._size)
end

function renderContent(self::CurvesWindow)
    col_flags = CImGui.ImGuiTableColumnFlags_WidthFixed
    if !CImGui.BeginTable("curves_tbl", 4,
            CImGui.ImGuiTableFlags_Borders | CImGui.ImGuiTableFlags_RowBg |
            CImGui.ImGuiTableFlags_ScrollY)
        return
    end

    CImGui.TableSetupScrollFreeze(0, 1)
    CImGui.TableSetupColumn("ID",     col_flags, 28.0 )
    CImGui.TableSetupColumn("Colors", col_flags, 250.0) 
    CImGui.TableSetupColumn("Width",  col_flags, 90.0 )
    CImGui.TableSetupColumn("Style",  col_flags, 65.0 )
    CImGui.TableHeadersRow()

    for node in getNodes(self._model._graph)
        if !(node isa ParametricCurveDependent || node isa SegmentSequenceDependent)
            continue
        end

        id = getGraphID(node)
        CImGui.TableNextRow()

        # --- ID Column ---
        CImGui.TableNextColumn()
        CImGui.Text("$id")

        # --- Colors Column ---
        CImGui.TableNextColumn()
        
        num_colors = length(node._colors)
        display_limit = 5
        changed = false

        # 1. Inline Color Pickers (Limited)
        for i in 1:min(num_colors, display_limit)
            new_color = color_edit3(node._colors[i], "##ccol$(id)_$i")
            
            if new_color !== nothing
                node._colors[i] = new_color
                changed = true
            end
            CImGui.SameLine()
        end

        # 2. "More" Button for Popup
        if num_colors > display_limit
            if CImGui.Button("...##more$id")
                CImGui.OpenPopup("color_popup_$id")
            end
            CImGui.SameLine()
        end

        # 3. Add Color Button (+)
        # Uses Cyan: RGB(0, 1, 1)
        if CImGui.Button("+##add$id")
            push!(node._colors, get_color((0,255,255)))
            changed = true
        end
        CImGui.SameLine()

        # 4. Remove Color Button (-)
        # Disabled if only 1 color remains
        if num_colors <= 1
            CImGui.BeginDisabled()
        end
        if CImGui.Button("-##rem$id")
            pop!(node._colors)
            changed = true
        end
        if num_colors <= 1
            CImGui.EndDisabled()
        end

        # 5. Popup logic for overflow colors
        if CImGui.BeginPopup("color_popup_$id")
            CImGui.Text("All Colors (Node $id)")
            CImGui.Separator()
            if CImGui.BeginChild("popup_scroll_$id", CImGui.ImVec2(150, 200), true)
                for i in 1:length(node._colors) # length might have changed via buttons
                    CImGui.Text("$i:") 
                    CImGui.SameLine()
                    new_color = color_edit3(node._colors[i], "##pcol$(id)_$i")
                    if new_color !== nothing
                        node._colors[i] = new_color
                        changed = true
                    end
                end
                CImGui.EndChild()
            end
            CImGui.EndPopup()
        end

        # Trigger updates if colors were edited, added, or removed
        if changed
            set_color(self._renderer,node)
        end

        # --- Width Column ---
        CImGui.TableNextColumn()
        w_ref = Ref(node._size)
        if CImGui.SliderFloat("##cw$id", w_ref, 1.0f0, 20.0f0)
            node._size = w_ref[]
            set_size(self._renderer,node)
        end

        # --- Style Column ---
        CImGui.TableNextColumn()
        cur_idx = something(findfirst(==(node._style), _CURVE_STYLE_VALUES), 1) - 1
        style_ref = Ref(Cint(cur_idx))
        if CImGui.Combo("##cst$id", style_ref, _CURVE_STYLE_LABELS, length(_CURVE_STYLE_LABELS))
            node._style = _CURVE_STYLE_VALUES[style_ref[] + 1]
            set_style(self._renderer,node)
        end
    end

    CImGui.EndTable()
end