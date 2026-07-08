
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
    openglD::OpenGLData = getOpenGL(app)
    if (self._whitebg[])
        glClearColor(1.0f0, 1.0f0, 1.0f0, 1.0f0)
    else
        openglD._backgroundCol = self._bgColor
        glClearColor(openglD._backgroundCol[1], openglD._backgroundCol[2], openglD._backgroundCol[3], 1.0f0)
    end
end

function renderContent(self::OptionsWindow, app::AppDNA)
    if (CImGui.Checkbox("White background", self._whitebg))
        setBackground(self, app)
    end

    CImGui.BeginDisabled(self._whitebg[])
    if (CImGui.ColorEdit3("Custom background color", self._bgColor, CImGui.ImGuiColorEditFlags_NoInputs))
        setBackground(self, app)
        println(self._bgColor)
    end
    CImGui.EndDisabled()
end
