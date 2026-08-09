mutable struct OptionsWindow <: WindowDNA
    _window::Window

    _whitebg::Ref{Bool}

    _pRend::PointRenderer
    _lRend::LineRenderer
    _tRend::TriangleRenderer
    _sRend::SphereRenderer

    _model::Model

    _oBgColor::Array{Cfloat}
    
    _selectedTheme::Ref{Int}


    _gizmoLength::Ref{Float32}
    _gizmoThickness::Ref{Float32}

    _aabbMin::Array{Cfloat}
    _aabbMax::Array{Cfloat}
    
    function OptionsWindow(color,pRenderer::PointRenderer,lRenderer::LineRenderer,tRenderer::TriangleRenderer,sRenderer::SphereRenderer,model::Model,aabbMin,aabbMax)
        whitebg = false
        oBgColor = Cfloat[color[1], color[2], color[3]]
        gizmoLength = 1.0
        gizmoThickness = 1.0
        selectedTheme= Ref(1)
        aabbMin = Cfloat[aabbMin[1],aabbMin[2],aabbMin[3]]
        aabbMax = Cfloat[aabbMax[1],aabbMax[2],aabbMax[3]]
        new(Window(), whitebg, pRenderer, lRenderer, tRenderer, sRenderer, model, oBgColor,selectedTheme, gizmoLength, gizmoThickness,aabbMin,aabbMax)
    end
end

_Window_(self::OptionsWindow)::Window = self._window
getWindowName(self::OptionsWindow) = "Options"

function _updateScene!(app::AppDNA)
    update!(getOpenGL(app), app._cam, true, UInt32(0))
end

function _setBackground(self::OptionsWindow, color::NTuple{3,Cfloat})

    for i in eachindex(self._oBgColor)
        self._oBgColor[i] = color[i]
    end

    glClearColor(color[1],color[2],color[3],1.0f0)
end

function _setBackground(self::OptionsWindow, app::AppDNA)
    if (self._whitebg[])
        glClearColor(1.0f0, 1.0f0, 1.0f0, 1.0f0)
    else
       glClearColor(self._oBgColor[1],self._oBgColor[2],self._oBgColor[3],1.0f0)
    end
    # ? updates so that the background changes instantly, instead of waiting for an actual scene_change
    _updateScene!(app)
end

function _setGizmo(self::OptionsWindow, app::AppDNA)
    gizmo = app._opengl._renderers.gizmo
    gizmo.ubo_size[1] = self._gizmoLength[]
    gizmo.ubo_size[2] = self._gizmoThickness[]
    _updateScene!(app)
end
function _setInfiniteAABBSize(self::OptionsWindow, app::AppDNA)
    app._opengl._ubo_aabb[1] = UBO_AABB(
        Vec4F(self._aabbMin[1],self._aabbMin[2],self._aabbMin[3],0.0),
        Vec4F(self._aabbMax[1],self._aabbMax[2],self._aabbMax[3],0.0)
    )
    _updateScene!(app)
end

function update_imgui_theme(style::UiStyle)
    s = get_style_style_ui(style)

    if s == dark
        CImGui.StyleColorsDark()
    elseif s == light
        CImGui.StyleColorsLight()
    elseif s == classic
        CImGui.StyleColorsClassic()
    end
end

function unpack_style_normal3(style,node)
    c = isnothing(node._color) ? get_style_color(style) : node._color
    st = isnothing(node._style) ? get_style_style_point(style) : node._style
    si = isnothing(node._size) ? get_style_size_int(style) : node._size
    return c, st, si
end

function unpack_style_multi_color3(style,node)
    cs = isnothing(node._colors) ? [get_style_color(style)] : node._colors
    st = isnothing(node._style) ? get_style_style_line(style) : node._style
    si = isnothing(node._size) ? get_style_size_float(style) : node._size
    return cs, st, si
end

function unpack_style1(style,node)
    c = isnothing(node._color) ? get_style_color(style) : node._color
    return c
end

function update_point_renderer!(self::OptionsWindow,node,color,style,size)
    ref = getObserver(node)._refs[getObserverID(node)]
    update_colors!(self._pRend,ref,color)
    update_styles!(self._pRend,ref,style)
    update_sizes!(self._pRend,ref,size)
end

function update_line_renderer!(self::OptionsWindow,node::ParametricCurveDependent,color,style,size)
    ref = getObserver(node)._refs[getObserverID(node)]
    update_colors!(self._lRend,ref,color)
    update_style!(self._lRend,ref,style)
    update_size!(self._lRend,ref,size)
end

function update_line_renderer!(self::OptionsWindow,node::SegmentSequenceDependent,color,style,size)
    ref = getObserver(node)._refs[getObserverID(node)]
    if node._break_every >= 2
        update_colors_dynamic!(self._lRend,ref,custom_interleaver(collect(Iterators.take(Iterators.cycle(color),length(node._values))),zero(UInt32),node._break_every))
        update_style_dynamic!(self._lRend,ref,style)
        update_size_dynamic!(self._lRend,ref,size)
    else
        update_colors_dynamic!(self._lRend,ref,Iterators.cycle(color))
        update_style_dynamic!(self._lRend,ref,style)
        update_size_dynamic!(self._lRend,ref,size)
    end
end

function update_triangle_renderer!(self::OptionsWindow,node,color)
    ref = getObserver(node)._refs[getObserverID(node)]
    update_color!(self._tRend,ref,color)
end

function update_sphere_renderer!(self::OptionsWindow,node,color)
    ref = getObserver(node)._indexes[getObserverID(node)]
    update_color!(self._sRend,ref,color)
end

function update_view!(self::OptionsWindow,theme::Theme,app::AppDNA)
    pointStyle = theme_style(theme,point_style)
    pointSetStyle = theme_style(theme,pointset_style)
    pointSequenceStyle = theme_style(theme,pointsequence_style)
    sphereStyle = theme_style(theme,sphere_style)
    parametricCurveStyle = theme_style(theme,parametriccurve_style)
    parametricSurfaceStyle = theme_style(theme,parametricsurface_style)
    triangleClusterStyle = theme_style(theme,trianglecluster_style)
    segmentSequencStyle = theme_style(theme,segmentsequence_style)
    backgroundStyle = theme_style(theme,background_style)
    uiStyle = theme_style(theme,ui_style)

    update_imgui_theme(uiStyle)
    _setBackground(self,backgroundStyle._color)

    for node in getNodes(self._model._graph)
        if (node isa PointDependent) 
            (c,st,si) = unpack_style_normal3(pointStyle,node)
            
            update_point_renderer!(self,node,c,st,si)

        elseif (node isa PointSetDependent)
            (c,st,si) = unpack_style_normal3(pointSetStyle,node)
            
            update_point_renderer!(self,node,c,st,si)

        elseif (node isa PointSequenceDependent)
            (c,st,si) = unpack_style_normal3(pointSequenceStyle,node)
            
            update_point_renderer!(self,node,c,st,si)

        elseif (node isa SphereDependent)
            c = unpack_style1(sphereStyle,node)
            update_sphere_renderer!(self,node,c)

        elseif (node isa ParametricCurveDependent)
            (cs,st,si) = unpack_style_multi_color3(parametricCurveStyle,node)
            update_line_renderer!(self,node,cs,st,si)

        elseif (node isa ParametricSurfaceDependent)
            c = unpack_style1(parametricSurfaceStyle,node)
            update_triangle_renderer!(self,node,c)

        elseif (node isa TriangleClusterDependent)
            c = unpack_style1(triangleClusterStyle,node)
            update_triangle_renderer!(self,node,c)

        elseif (node isa SegmentSequenceDependent)
            (cs,st,si) = unpack_style_multi_color3(segmentSequencStyle,node)
            update_line_renderer!(self,node,cs,st,si)
        end
    end
    _updateScene!(app)
end

function renderContent(self::OptionsWindow, app::AppDNA)
    if (CImGui.Checkbox("White background", self._whitebg))
        _setBackground(self, app)
    end

    CImGui.BeginDisabled(self._whitebg[])
    if (CImGui.ColorEdit3("Custom background color", self._oBgColor, CImGui.ImGuiColorEditFlags_NoInputs))
        _setBackground(self, app)
    end
    CImGui.EndDisabled()
    
    CImGui.SameLine()
    if (CImGui.Button("Default"))
        defcol = getOpenGL(app)._backgroundCol
        self._oBgColor = Cfloat[defcol[1], defcol[2], defcol[3]]
        _setBackground(self, app)
    end


    if CImGui.BeginCombo("Theme", Themes[self._selectedTheme[]]._name)

        for i in eachindex(Themes)

            selected = (self._selectedTheme[] == i)

            if CImGui.Selectable(Themes[i]._name, selected)

                self._selectedTheme[] = i

                theme = Themes[i]

                update_theme!(app,theme)

                update_view!(self,theme,app)
            end

            if selected
                CImGui.SetItemDefaultFocus()
            end
        end

        CImGui.EndCombo()
    end


    if (CImGui.CollapsingHeader("Gizmo settings"))
        if (CImGui.SliderFloat("Length", self._gizmoLength, 0.5, 2.0))
            _setGizmo(self, app)
        end
        if (CImGui.SliderFloat("Thickness", self._gizmoThickness, 0.5, 2.0))
            _setGizmo(self, app)
        end
    end

    if (CImGui.CollapsingHeader("Infinite AABB settings"))
        if (CImGui.DragFloat3("Minimum", self._aabbMin, 1.0, -100.0, -1.0))
            _setInfiniteAABBSize(self, app)
        end
        if (CImGui.DragFloat3("Maximum", self._aabbMax, 1.0, 1.0, 100.0))
            _setInfiniteAABBSize(self, app)
        end
    end
end


