abstract type Renderer end

clear!(::Renderer)::Nothing = nothing
destroy!(::Renderer)::Nothing = nothing

pre_draw!(::Renderer, ::Camera, ::GLFWData)::Nothing = nothing
draw_ui!(::Renderer, ::Camera, ::GLFWData)::Nothing = nothing
draw_opaque!(::Renderer, ::Camera, ::GLFWData)::Nothing = nothing
draw_behind_opaque!(::Renderer, ::Camera, ::GLFWData)::Nothing = nothing
visible_behind_opaque(::Renderer)::Bool = false
draw_transparent!(::Renderer, ::Camera, ::GLFWData)::Nothing = nothing

function packUnorm4x8(v::Vec3T{T})::UInt32 where T<:AbstractFloat
    return packUnorm4x8(Vec4F(Float32(v[1]), Float32(v[2]), Float32(v[3]), Float32(1.0)))
end
function packUnorm4x8(v::Vec4T{T})::UInt32 where T<:AbstractFloat
    c1 = UInt32(round(clamp(v[1], 0.0, 1.0) * 255.0))
    c2 = UInt32(round(clamp(v[2], 0.0, 1.0) * 255.0))
    c3 = UInt32(round(clamp(v[3], 0.0, 1.0) * 255.0))
    c4 = UInt32(round(clamp(v[4], 0.0, 1.0) * 255.0))
    return (c4 << 24) | (c3 << 16) | (c2 << 8) | c1
end
function is_packed_opaque(packed::UInt32)::Bool
    return return (packed & 0xFF000000) == 0xFF000000
end

include("gizmo_renderer.jl")
include("point_renderer.jl")
include("line_renderer.jl")
include("sphere_renderer.jl")
include("triangle_renderer.jl")

const RENDERER_FACTORIES::Dict{DataType,Function} = Dict{DataType,Function}(
    GizmoRenderer => (loader::PipelineLoader, scale::Float32) -> GizmoRenderer(loader, scale),
    PointRenderer => (loader::PipelineLoader, scale::Float32) -> PointRenderer(loader),
    LineRenderer => (loader::PipelineLoader, scale::Float32) -> LineRenderer(loader),
    SphereRenderer => (loader::PipelineLoader, scale::Float32) -> SphereRenderer(loader),
    TriangleRenderer => (loader::PipelineLoader, scale::Float32) -> TriangleRenderer(loader)
)

add_renderer(type::DataType, factory::Function) = RENDERER_FACTORIES[type] = factory
initialize_renderers(loader::PipelineLoader, scale::Float32) = Dict(type => factory(loader, scale) for (type, factory) in RENDERER_FACTORIES)
function initialize_renderers!(renderers::Dict{DataType,Renderer}, loader::PipelineLoader, scale::Float32)::Dict{DataType,Renderer}
    length(renderers) == length(RENDERER_FACTORIES) && return renderers
    for (type, factory) in RENDERER_FACTORIES
        get!(renderers, type) do ;
            factory(loader, scale);
        end
    end
    return renderers
end
clear!(renderers::Dict{DataType,Renderer}) = foreach(clear!, values(renderers))
destroy!(renderers::Dict{DataType,Renderer}) = foreach(destroy!, values(renderers))

function pre_draw!(renderers::Dict{DataType,Renderer}, camera::Camera, window::GLFWData)
    for renderer::Renderer in values(renderers)
        pre_draw!(renderer, camera, window)
    end
    return nothing
end
function draw_ui!(renderers::Dict{DataType,Renderer}, camera::Camera, window::GLFWData)
    for renderer::Renderer in values(renderers)
        draw_ui!(renderer, camera, window)
    end
    return nothing
end

const FALLBACK_BEHIND_SIG = Tuple{typeof(draw_behind_opaque!), Renderer, Camera, GLFWData}
function draw_opaque!(renderers::Dict{DataType,Renderer}, camera::Camera, window::GLFWData, ::Val{T}) where T
    for renderer in values(renderers)
        if visible_behind_opaque(renderer) == T
            draw_opaque!(renderer, camera, window)
        end
    end
end
function draw_behind_opaque!(renderers::Dict{DataType,Renderer}, camera::Camera, window::GLFWData)
    for renderer::Renderer in values(renderers)
        draw_behind_opaque!(renderer, camera, window)
    end
    return nothing
end
function draw_transparent!(renderers::Dict{DataType,Renderer}, camera::Camera, window::GLFWData)
    for renderer::Renderer in values(renderers)
        draw_transparent!(renderer, camera, window)
    end
    return nothing
end