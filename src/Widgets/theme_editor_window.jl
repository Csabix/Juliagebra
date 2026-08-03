mutable struct ThemeEditorWindow <: WindowDNA
    _window::Window
    _selectedTheme::Ref{Int}

    function ThemeEditorWindow()
        new(Window(), Ref(1))
    end
end

_Window_(self::ThemeEditorWindow) = self._window
getWindowName(self::ThemeEditorWindow) = "Theme editor"

