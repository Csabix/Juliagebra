
mutable struct OptionsWindow <: WindowDNA
    _window::Window

    _whitebg::Ref{Bool}

    OptionsWindow() = new(Window(), false)
end

_Window_(self::OptionsWindow)::Window = self._window
getWindowName(self::OptionsWindow) = "Options"

function setBackground(self::OptionsWindow, app::AppDNA)
    openglD::OpenGLData = getOpenGL(app)
    if (self._whitebg[])
        glClearColor(1.0f0, 1.0f0, 1.0f0, 1.0f0)
    else
        glClearColor(openglD._backgroundCol[1], openglD._backgroundCol[2], openglD._backgroundCol[3], 1.0f0)
    end
end

function renderContent(self::OptionsWindow, app::AppDNA)
    if (CImGui.Checkbox("White background", self._whitebg))
        setBackground(self, app)
    end
end
