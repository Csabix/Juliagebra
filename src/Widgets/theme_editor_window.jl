mutable struct ThemeEditorWindow <: WindowDNA
    _window::Window
    _selectedTheme::Ref{Int32}

   function ThemeEditorWindow()
        new(Window(), Ref{Int32}(0))
    end
end

_Window_(self::ThemeEditorWindow) = self._window
getWindowName(self::ThemeEditorWindow) = "Theme editor"

const _UI_STYLE_LABELS = ["dark","light","classic"]
const _UI_STYLE_VALUES = [dark,light,classic]

function pointStyleToIndex(st)
    return something(findfirst(==(st), _POINT_STYLE_LABELS), 1) - 1
end

function curveStyleToIndex(st)
    return something(findfirst(==(st), _CURVE_STYLE_VALUES), 1) - 1
end


function DrawStyleEditor!(name, style)

    CImGui.TableNextRow()

    CImGui.TableSetColumnIndex(0)
    CImGui.Text(name)

    CImGui.TableSetColumnIndex(1)

    if (hasproperty(style,:_color))
        if style isa BackGroundStyle
            color = Ref{NTuple{3, Cfloat}}(style._color)
            if CImGui.ColorEdit3("##Color$name", color)
                style._color = color[]
            end
        else
            new_color = color_edit3(style._color, "##color$name")
            if new_color !== nothing
            style._color = new_color
            end
        end
    end

    CImGui.TableSetColumnIndex(2)

    if hasproperty(style, :_style)
        if style isa SegmentSequenceStyle || style isa ParametricCurveStyle
            labels = _CURVE_STYLE_LABELS
            values = _CURVE_STYLE_VALUES
        elseif style isa UiStyle
            labels = _UI_STYLE_LABELS
            values = _UI_STYLE_VALUES
        else
            labels = _POINT_STYLE_LABELS
            values = _POINT_STYLE_VALUES
        end

        midx = Ref{Int32}(something(findfirst(==(style._style), values), 1) - 1)

        if CImGui.Combo("##Style$name", midx, labels, length(labels))
            style._style = values[midx[] + 1]
        end
    end


    CImGui.TableSetColumnIndex(3)
    if (hasproperty(style,:_size))
        if style isa SegmentSequenceStyle || style isa ParametricCurveStyle
            sz=  Ref(something(style._size, 5.0f0))

            if CImGui.SliderFloat("##Size$name", sz, 1.0f0, 20.0f0)
                style._size = sz[]
            end

        else
            sz = Ref{Int32}(something(style._size,25))

            if CImGui.SliderInt("##Size$name", sz, 0, 255)
                style._size = UInt8(round(UInt8, sz[]))
            end
        end
    end
end


function renderContent(self::ThemeEditorWindow,app::AppDNA)
  
    names = [t._name for t in Themes]
    CImGui.Combo("Theme", self._selectedTheme,names,length(names))

    if !CImGui.BeginTable("Theme_editor", 4,
            CImGui.ImGuiTableFlags_Borders |
            CImGui.ImGuiTableFlags_RowBg   |
            CImGui.ImGuiTableFlags_ScrollY)
        return
    end

      theme = Themes[self._selectedTheme[] + 1]

        
    CImGui.TableSetupColumn("Name")
    CImGui.TableSetupColumn("Color")
    CImGui.TableSetupColumn("Style")
    CImGui.TableSetupColumn("Size")

    CImGui.TableHeadersRow()
    
    for (k,v) in theme._styles
            DrawStyleEditor!(string(k), v)
    end
    
    CImGui.EndTable()
end