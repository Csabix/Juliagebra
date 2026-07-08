
mutable struct OptionsWindow <: WindowDNA
    _window::Window

    _whitebg::Ref{Bool}

    OptionsWindow() = new(Window(), false)
end

_Window_(self::OptionsWindow)::Window = self._window
getWindowName(self::OptionsWindow) = "Options"

function setBackground()
    println("Bg change!")
end

function renderContent(self::OptionsWindow)
    if (CImGui.Checkbox("White background", self._whitebg))
        setBackground()
    end
end
