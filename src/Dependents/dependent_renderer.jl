# ? ---------------------------------
# ! RendererDNA
# ? ---------------------------------

mutable struct Renderer{T<:RenderedDependentDNA} <: ObserverDNA{T}
    _observer::Observer{T}
    _context::OpenGLData
end

function Renderer{T}(context::OpenGLData) where {T<:RenderedDependentDNA}
    observer = Observer{T}()
    return Renderer{T}(observer,context)
end

_Renderer_(self::RendererDNA)::Renderer = error("Missing \"_Renderer_\" func for instance of RendererDNA")
_Observer_(self::RendererDNA)::Observer = return _Renderer_(self)._observer

draw!(self::RendererDNA,vp,selectedID,pickedID,cam,shrd) = error("Missing func!")
draw_occluded!(self::RendererDNA,vp,selectedID,pickedID,cam,shrd) = begin end
destroy!(self::RendererDNA) = error("Missing \"destroy!\" func for instance of RendererDNA")
(plan2Dependent(self::RendererDNA{T},plan::PlanDNA)::T) where {T<:RenderedDependentDNA} = error("Missing func for $(typeof(self)) - $(typeof(plan))!")
addedAll!(self::RendererDNA) = error("Missing func!")
