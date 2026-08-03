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

    
    function OptionsWindow(color,pRenderer::PointRenderer,lRenderer::LineRenderer,tRenderer::TriangleRenderer,sRenderer::SphereRenderer,model::Model)
        whitebg = false
        oBgColor = Cfloat[color[1], color[2], color[3]]
        dBgColor = Cfloat[0.15f0,0.15f0,0.15f0]
        gizmoLength = 1.0
        gizmoThickness = 1.0
        selectedTheme= Ref(1)
        new(Window(), whitebg, pRenderer, lRenderer, tRenderer, sRenderer, model, oBgColor,selectedTheme, gizmoLength, gizmoThickness)
    end
end

_Window_(self::OptionsWindow)::Window = self._window
getWindowName(self::OptionsWindow) = "Options"

function _updateScene!(app::AppDNA)
    update!(getOpenGL(app), app._cam, true, UInt32(0))
end
function _setBackground(self::OptionsWindow, app::AppDNA)
    if (self._whitebg[])
        glClearColor(1.0f0, 1.0f0, 1.0f0, 1.0f0)
    else
        glClearColor(self._oBgColor[1], self._oBgColor[2], self._oBgColor[3], 1.0f0)
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

            #setStyle!(self._pRend, theme_style(theme, point_style))
            #setStyle!(self._lRend, theme_style(theme, segmentsequence_style))
            #setStyle!(self._tRend, theme_style(theme, trianglecluster_style))
            #setStyle!(self._sRend, theme_style(theme, sphere_style))

            _updateScene!(app)
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
end


