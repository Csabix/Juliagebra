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
    end
end

_Window_(self::OptionsWindow)::Window = self._window
getWindowName(self::OptionsWindow) = "Options"

function setBackground(self::OptionsWindow, app::AppDNA)
    if (self._whitebg[])
        glClearColor(1.0f0, 1.0f0, 1.0f0, 1.0f0)

    elseif (self._darkTheme[])
        glClearColor(self._dBgColor[1], self._dBgColor[2], self._dBgColor[3], 1.0f0)
        
    else
        glClearColor(self._oBgColor[1], self._oBgColor[2], self._oBgColor[3], 1.0f0)
    end
    # updates so that the background changes instantly, instead of waiting for an actual scene_change
    update!(getOpenGL(app), app._cam, true, UInt32(0))
end


function renderContent(self::OptionsWindow, app::AppDNA)
    
    CImGui.BeginDisabled(self._darkTheme[])
    if (CImGui.Checkbox("White background", self._whitebg))
        setBackground(self, app)
    end
    CImGui.EndDisabled()

    CImGui.BeginDisabled(self._whitebg[])

    if (CImGui.Checkbox("Dark theme", self._darkTheme))
        setBackground(self,app)
    end

    CImGui.BeginDisabled(self._darkTheme[])

    if (CImGui.ColorEdit3("Custom background color", self._oBgColor, CImGui.ImGuiColorEditFlags_NoInputs))
        setBackground(self, app)
    end

    CImGui.EndDisabled()
    CImGui.EndDisabled()
    
    CImGui.SameLine()
    if (CImGui.Button("Default"))
        defcol = getOpenGL(app)._backgroundCol
        self._oBgColor = Cfloat[defcol[1], defcol[2], defcol[3]]
        setBackground(self, app)
    end
end


