using Base.Iterators: cycle, take, map as imap

function packUnorm4x8(v::Vec3T{T})::UInt32 where T <: AbstractFloat
    return  packUnorm4x8(Vec4F(Float32(v[1]),Float32(v[2]),Float32(v[3]),Float32(1.0)))
end
function packUnorm4x8(v::Vec4T{T})::UInt32 where T <: AbstractFloat
    c1 = UInt32(round(clamp(v[1], 0.0, 1.0) * 255.0))
    c2 = UInt32(round(clamp(v[2], 0.0, 1.0) * 255.0))
    c3 = UInt32(round(clamp(v[3], 0.0, 1.0) * 255.0))
    c4 = UInt32(round(clamp(v[4], 0.0, 1.0) * 255.0))
    return (c4 << 24) | (c3 << 16) | (c2 << 8) | c1
end
@inline function is_packed_opaque(packed::UInt32)::Bool
    return return (packed & 0xFF000000) == 0xFF000000
end

include("point_renderer.jl")
include("line_renderer.jl")
include("sphere_renderer.jl")
include("triangle_renderer.jl")

# Extension hook: users outside Juliagebra can push a zero-arg factory here to
# have an extra primitive renderer instantiated alongside the built-in ones.
# Each factory's return value must implement (no-op allowed): destroy!, added_all!,
# sync_all! -> Bool (true if a redraw is needed), pre_draw(::_, cam, shrd),
# opaque(::_, cam, shrd), transparent(::_, cam, shrd).
# Extras are treated as depth-writing occluders, so they are invoked from
# `opaque_occluder` (alongside sphere/triangle), not `opaque` (line/point).
#
# Ordering: PrimitiveRenderers() runs before create_dependent_observers, so an
# external primitive factory may stash its renderer in a Ref for the paired
# observer factory (registered via `register_dependent_observer!`) to read.
const _EXTRA_PRIMITIVE_FACTORIES = Function[]
register_primitive_renderer!(factory::Function) = (push!(_EXTRA_PRIMITIVE_FACTORIES, factory); nothing)

struct PrimitiveRenderers
    point::PointRenderer
    line::LineRenderer
    sphere::SphereRenderer
    triangle::TriangleRenderer
    extras::Vector{Any}

    function PrimitiveRenderers()
        extras = Any[f() for f in _EXTRA_PRIMITIVE_FACTORIES]
        return new(PointRenderer(),LineRenderer(),SphereRenderer(),TriangleRenderer(),extras)
    end
end

function destroy!(renderers::PrimitiveRenderers)::Nothing
    destroy!(renderers.point)
    destroy!(renderers.line)
    destroy!(renderers.sphere)
    destroy!(renderers.triangle)
    for e in renderers.extras; destroy!(e); end
    return nothing
end

function added_all!(renderers::PrimitiveRenderers)::Nothing
    added_all!(renderers.point)
    added_all!(renderers.line)
    added_all!(renderers.sphere)
    added_all!(renderers.triangle)
    for e in renderers.extras; added_all!(e); end
    return nothing
end

function sync_all!(renderers::PrimitiveRenderers)::Bool
    redraw_scene::Bool = false
    redraw_scene |= sync_all!(renderers.point)
    redraw_scene |= sync_all!(renderers.line)
    redraw_scene |= sync_all!(renderers.sphere)
    redraw_scene |= sync_all!(renderers.triangle)
    for e in renderers.extras; redraw_scene |= sync_all!(e); end
    return redraw_scene
end

function pre_draw(renderers::PrimitiveRenderers,cam::Camera,shrd::SharedData)::Nothing
    pre_draw(renderers.line,cam,shrd)
    pre_draw(renderers.triangle,cam,shrd)
    for e in renderers.extras; pre_draw(e,cam,shrd); end
    return nothing
end

function opaque_occluder(renderers::PrimitiveRenderers,cam::Camera,shrd::SharedData)::Nothing
    opaque(renderers.sphere,cam,shrd)
    opaque(renderers.triangle,cam,shrd)
    for e in renderers.extras; opaque(e,cam,shrd); end
    return nothing
end

function opaque(renderers::PrimitiveRenderers,cam::Camera,shrd::SharedData)::Nothing
    opaque(renderers.line,cam,shrd)
    opaque(renderers.point,cam,shrd)
    return nothing
end

function behind_opaque(renderers::PrimitiveRenderers,cam::Camera,shrd::SharedData)::Nothing
    behind_opaque(renderers.line,cam,shrd)
    behind_opaque(renderers.point,cam,shrd)
    return nothing
end

function transparent(renderers::PrimitiveRenderers,cam::Camera,shrd::SharedData)::Nothing
    transparent(renderers.line,cam,shrd)
    transparent(renderers.sphere,cam,shrd)
    transparent(renderers.triangle,cam,shrd)
    for e in renderers.extras; transparent(e,cam,shrd); end
    return nothing
end

function reset!(renderers::PrimitiveRenderers)::Nothing
    reset!(renderers.point)
    reset!(renderers.line)
    reset!(renderers.sphere)
    reset!(renderers.triangle)
    return nothing
end