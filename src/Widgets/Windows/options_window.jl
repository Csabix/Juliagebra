mutable struct OptionsWindow <: WindowDNA
    _window::Window

    _whitebg::Ref{Bool}
    _darkTheme::Ref{Bool}

    _pRend::PointRenderer
    _lRend::LineRenderer
    _tRend::TriangleRenderer
    _sRend::SphereRenderer

    _model::Model

    _oBgColor::Array{Cfloat}
    _dBgColor::Array{Cfloat}
    
    function OptionsWindow(color,pRenderer::PointRenderer,lRenderer::LineRenderer,tRenderer::TriangleRenderer,sRenderer::SphereRenderer,model::Model)
        new(Window(), false, false, pRenderer, lRenderer, tRenderer, sRenderer, model,
        Cfloat[color[1], color[2], color[3]],
        Cfloat[0.15f0,0.15f0,0.15f0])
    _gizmoLength::Ref{Float32}
    _gizmoThickness::Ref{Float32}

    function OptionsWindow(color)
        whitebg = false
        bgColor = Cfloat[color[1], color[2], color[3]]
        gizmoLength = 1.0
        gizmoThickness = 1.0
        new(Window(), whitebg, bgColor, gizmoLength, gizmoThickness)
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

    elseif (self._darkTheme[])
        glClearColor(self._dBgColor[1], self._dBgColor[2], self._dBgColor[3], 1.0f0)
        
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
    
    CImGui.BeginDisabled(self._darkTheme[])
    if (CImGui.Checkbox("White background", self._whitebg))
        _setBackground(self, app)
    end
    CImGui.EndDisabled()

    CImGui.BeginDisabled(self._whitebg[])

    if (CImGui.Checkbox("Dark theme", self._darkTheme))
        setBackground(self,app)
    end

    CImGui.BeginDisabled(self._darkTheme[])

    if (CImGui.ColorEdit3("Custom background color", self._oBgColor, CImGui.ImGuiColorEditFlags_NoInputs))
        setBackground(self, app)
    if (CImGui.ColorEdit3("Custom background color", self._bgColor, CImGui.ImGuiColorEditFlags_NoInputs))
        _setBackground(self, app)
    end

    CImGui.EndDisabled()
    CImGui.EndDisabled()
    
    CImGui.SameLine()
    if (CImGui.Button("Default"))
        defcol = getOpenGL(app)._backgroundCol
        self._oBgColor = Cfloat[defcol[1], defcol[2], defcol[3]]
        setBackground(self, app)
        self._bgColor = Cfloat[defcol[1], defcol[2], defcol[3]]
        _setBackground(self, app)
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


