
mutable struct OptionsWindow <: WindowDNA
    _window::Window

    _whitebg::Ref{Bool}
    _bgColor::Array{Cfloat}

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
    else
        glClearColor(self._bgColor[1], self._bgColor[2], self._bgColor[3], 1.0f0)
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
    if (CImGui.ColorEdit3("Custom background color", self._bgColor, CImGui.ImGuiColorEditFlags_NoInputs))
        _setBackground(self, app)
    end
    CImGui.EndDisabled()
    
    CImGui.SameLine()
    if (CImGui.Button("Default"))
        defcol = getOpenGL(app)._backgroundCol
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
