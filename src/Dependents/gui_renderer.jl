
# ? ---------------------------------
# ! GuiRendererDNA
# ? ---------------------------------

@kwdef mutable struct GuiRenderer{T<:GuiDependentDNA} <: ObserverDNA{T}
    _observer::Observer{T} = Observer{T}()
end

_GuiRenderer_(self::GuiRendererDNA)::GuiRenderer = error("Missing func!")
_Observer_(self::GuiRendererDNA)::Observer = return _GuiRenderer_(self)._observer
