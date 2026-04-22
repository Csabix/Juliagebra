
mutable struct CurvesWindow <: WindowDNA
    _window::Window
    _graph::DependentGraphDNA

    CurvesWindow(graph::DependentGraphDNA) = new(Window(), graph)
end

_Window_(self::CurvesWindow)::Window = self._window
getWindowName(self::CurvesWindow) = "Curves"

const _CURVE_STYLE_LABELS = ["-", "--", ":", "~", "-.", "->", "<-"]
# values match SOLID=1..ARROW=6, ARROW_REVERSED=ARROW|(1<<7)=134 from line_renderer.jl
const _CURVE_STYLE_VALUES = UInt8[1, 2, 3, 4, 5, 6, 134]

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

    for node in getNodes(self._graph)
        node isa ParametricCurveDependent || continue

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
            cur_color = _unpack_rgb(node._colors[i])
            new_color = color_edit3(cur_color, "##ccol$(id)_$i")
            
            if new_color !== nothing
                node._colors[i] = _pack_rgb(new_color)
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
            push!(node._colors, _pack_rgb(Vec3F(0f0, 1f0, 1f0)))
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
                    cur_color = _unpack_rgb(node._colors[i])
                    CImGui.Text("$i:") 
                    CImGui.SameLine()
                    new_color = color_edit3(cur_color, "##pcol$(id)_$i")
                    if new_color !== nothing
                        node._colors[i] = _pack_rgb(new_color)
                        changed = true
                    end
                end
                CImGui.EndChild()
            end
            CImGui.EndPopup()
        end

        # Trigger updates if colors were edited, added, or removed
        if changed
            node._update_color = true
            afterNodeEval(node)
        end

        # --- Width Column ---
        CImGui.TableNextColumn()
        w_ref = Ref(node._width)
        if CImGui.SliderFloat("##cw$id", w_ref, 1.0f0, 20.0f0)
            node._width = w_ref[]
            afterNodeEval(node)
        end

        # --- Style Column ---
        CImGui.TableNextColumn()
        cur_idx = something(findfirst(==(node._type), _CURVE_STYLE_VALUES), 1) - 1
        style_ref = Ref(Cint(cur_idx))
        if CImGui.Combo("##cst$id", style_ref, _CURVE_STYLE_LABELS, length(_CURVE_STYLE_LABELS))
            node._type = _CURVE_STYLE_VALUES[style_ref[] + 1]
            afterNodeEval(node)
        end
    end

    CImGui.EndTable()
end