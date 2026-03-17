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

pre_draw!(self::RendererDNA,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing = begin end
id_pass!(self::RendererDNA,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing = begin end
opaque_pass!(self::RendererDNA,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing = begin end
is_occluder(self::RendererDNA)::Bool = true
behind_opaque_pass!(self::RendererDNA,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing = begin end
transparent_pass!(self::RendererDNA,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing = begin end

destroy!(self::RendererDNA) = error("Missing \"destroy!\" func for instance of RendererDNA")
addedAll!(self::RendererDNA) = error("Missing func!")

