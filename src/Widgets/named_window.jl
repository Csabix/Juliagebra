
mutable struct NamedWindow <: WindowDNA
    _window::Window
    _name::String

    function NamedWindow(name::String)
        window = Window()
        new(window,name)
    end
end

_Window_(self::NamedWindow)::Window = return self._window

getWindowName(self::NamedWindow) = return self._name

function renderContent(self::NamedWindow)

end