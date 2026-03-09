
# ? ---------------------------------
# ! GuiDependentsWindow
# ? ---------------------------------

Type2Id(::Type{ToggleRenderer}) = 1
Type2Id(::Type{SliderRenderer}) = 2
Type2Id(::Type{TextBoxRenderer}) = 3

mutable struct GuiDependentsWindow <: WindowDNA
    _window::Window
    _pool::ObserverPool{GuiRendererDNA}
    
    function GuiDependentsWindow()
        window = Window()
        pool = ObserverPool{GuiRendererDNA}()
        fill!(pool,[
            ToggleRenderer() # ? 1
            SliderRenderer() # ? 2
            TextBoxRenderer() # ? 3
            ])

        new(window,pool)
    end
end

_Window_(self::GuiDependentsWindow)::Window = self._window
getWindowName(self::GuiDependentsWindow) = return "GuiDependents"

function renderContent(self::GuiDependentsWindow)
    for activeRenderer in self._pool
        # TODO: Continue this.
        if !isnothing(activeRenderer)
            render!(activeRenderer)
        end
    end
end