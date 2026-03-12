abstract type RendererBase end

pre_draw!(self::RendererBase,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing = begin end
id_pass!(self::RendererBase,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing = begin end
opaque_pass!(self::RendererBase,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing = begin end
is_occluder(self::RendererBase)::Bool = true
behind_opaque_pass!(self::RendererBase,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing = begin end
transparent_pass!(self::RendererBase,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing = begin end