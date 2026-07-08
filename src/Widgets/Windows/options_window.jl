
mutable struct OptionsWindow <: WindowDNA
    _window::Window

    _whitebg::Ref{Bool}
    _bgColor::Array{Cfloat}

    function OptionsWindow(color)
        new(Window(), false, Cfloat[color[1], color[2], color[3]])
    end
end

_Window_(self::OptionsWindow)::Window = self._window
getWindowName(self::OptionsWindow) = "Options"

function setBackground(self::OptionsWindow, app::AppDNA)
    if (self._whitebg[])
        glClearColor(1.0f0, 1.0f0, 1.0f0, 1.0f0)
    else
        glClearColor(self._bgColor[1], self._bgColor[2], self._bgColor[3], 1.0f0)
    end
    # updates so that the background changes instantly, instead of waiting for an actual scene_change
    update!(getOpenGL(app), app._cam, true, UInt32(0))
end

function renderContent(self::OptionsWindow, app::AppDNA)
    if (CImGui.Checkbox("White background", self._whitebg))
        setBackground(self, app)
    end

    CImGui.BeginDisabled(self._whitebg[])
    if (CImGui.ColorEdit3("Custom background color", self._bgColor, CImGui.ImGuiColorEditFlags_NoInputs))
        setBackground(self, app)
    end
    CImGui.EndDisabled()
    
    CImGui.SameLine()
    if (CImGui.Button("Default"))
        defcol = getOpenGL(app)._backgroundCol
        self._bgColor = Cfloat[defcol[1], defcol[2], defcol[3]]
        setBackground(self, app)
    end
end
