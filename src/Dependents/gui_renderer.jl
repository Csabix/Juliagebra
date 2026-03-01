
# ? ---------------------------------
# ! GuiRendererDNA
# ? ---------------------------------

mutable struct GuiRenderer{T<:GuiDependentDNA} <: ObserverDNA{T}
    _observer::Observer{T}

    function GuiRenderer{T}() where {T<:GuiDependentDNA}
        observer = Observer{T}()
        return GuiRenderer{T}(observer)
    end
end

_GuiRenderer_(self::GuiRendererDNA)::GuiRenderer = error("Missing func!")
_Observer_(self::GuiRendererDNA)::Observer = return _GuiRenderer_(self)._observer

