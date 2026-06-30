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

struct PrimitiveRenderers
    point::PointRenderer
    line::LineRenderer
    sphere::SphereRenderer
    triangle::TriangleRenderer

    function PrimitiveRenderers(loader::PipelineLoader)
        return new(PointRenderer(loader),LineRenderer(loader),SphereRenderer(loader),TriangleRenderer(loader))
    end
end

function destroy!(renderers::PrimitiveRenderers)::Nothing
    destroy!(renderers.point)
    destroy!(renderers.line)
    destroy!(renderers.sphere)
    destroy!(renderers.triangle)
    return nothing
end

function added_all!(renderers::PrimitiveRenderers)::Nothing
    added_all!(renderers.point)
    added_all!(renderers.line)
    added_all!(renderers.sphere)
    added_all!(renderers.triangle)
    return nothing
end

function sync_all!(renderers::PrimitiveRenderers)::Bool
    redraw_scene::Bool = false
    redraw_scene |= sync_all!(renderers.point)
    redraw_scene |= sync_all!(renderers.line)
    redraw_scene |= sync_all!(renderers.sphere)
    redraw_scene |= sync_all!(renderers.triangle)
    return redraw_scene
end

function pre_draw(renderers::PrimitiveRenderers,cam::Camera,window::GLFWData)::Nothing
    pre_draw(renderers.line,cam,window)
    pre_draw(renderers.triangle,cam,window)
    return nothing
end

function opaque_occluder(renderers::PrimitiveRenderers,cam::Camera,window::GLFWData)::Nothing
    opaque(renderers.sphere,cam,window)
    opaque(renderers.triangle,cam,window)
    return nothing
end

function opaque(renderers::PrimitiveRenderers,cam::Camera,window::GLFWData)::Nothing
    opaque(renderers.line,cam,window)
    opaque(renderers.point,cam,window)
    return nothing
end

function behind_opaque(renderers::PrimitiveRenderers,cam::Camera,window::GLFWData)::Nothing
    behind_opaque(renderers.line,cam,window)
    behind_opaque(renderers.point,cam,window)
    return nothing
end

function transparent(renderers::PrimitiveRenderers,cam::Camera,window::GLFWData)::Nothing
    transparent(renderers.line,cam,window)
    transparent(renderers.sphere,cam,window)
    transparent(renderers.triangle,cam,window)
    return nothing
end

function reset!(renderers::PrimitiveRenderers)::Nothing
    reset!(renderers.point)
    reset!(renderers.line)
    reset!(renderers.sphere)
    reset!(renderers.triangle)
    return nothing
end