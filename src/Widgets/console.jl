
mutable struct Console <: WindowDNA
    _window::Window
    
    function Console()
        window = Window()

        new(window)
    end
end

_Window_(self::Console)::Window = return self._window
getWindowName(self::Console) = return "Console"

function renderContent(self::Console)
    
end
