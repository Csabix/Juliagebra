mutable struct ParametricSurface{Range<:AbstractRange}
    values::Matrix{Vec3D}
    uRange::Range
    vRange::Range

    function ParametricSurface(uRange::Range, vRange::Range) where {Range<:AbstractRange}
        new{Range}(Matrix{Vec3D}(undef, length(uRange), length(vRange)), uRange, vRange)
    end
end

struct ParametricSurfaceDrawData
    handle::UInt32
    color::UInt32
end

Base.@propagate_inbounds convert_result(ps::ParametricSurface,result,u,v) = (ps.values[u,v] = Vec3D(result);ps)
Base.@propagate_inbounds convert_result(ps::ParametricSurface,result::Tuple,u,v) = (ps.values[u,v] = Vec3D(result...);ps)
Base.@propagate_inbounds convert_result(ps::ParametricSurface,result::Vec3F,u,v) = (ps.values[u,v] = Vec3D(result);ps)
Base.@propagate_inbounds convert_result(ps::ParametricSurface,result::Vec3D,u,v) = (ps.values[u,v] = result;ps)
Base.@propagate_inbounds convert_result(ps::ParametricSurface,::Nothing,u,v) = (ps.values[u,v] = Vec3DNan;ps)

function eval_node(element::ParametricSurface, callback::Function, arguments::Vector{Any})::Any
    _fill_surface!(element, callback, arguments...)
    return element
end
function _fill_surface!(ps::ParametricSurface, callback::F, args::Vararg{Any,N}) where {F,N}
    for (v, vf) in enumerate(ps.vRange), (u, uf) in enumerate(ps.uRange)
        @inbounds convert_result(ps, callback(uf, vf, args...), u, v)
    end
    return ps
end

function render_node(ps::ParametricSurface, pdata::ParametricSurfaceDrawData, renderers::Dict{DataType,Renderer}, id::UInt32)::ParametricSurfaceDrawData
    triangle_renderer::TriangleRenderer = renderers[TriangleRenderer]
    triangles = get_triangulated(ps.values)
    if pdata.handle == 0
        handle = add!(triangle_renderer, triangles, mat4(1.0f0), pdata.color, false, id)
        return ParametricSurfaceDrawData(handle, pdata.color)
    else
        update_coords!(triangle_renderer, pdata.handle, triangles)
        return pdata
    end
end

PrimitivesOf(self::ParametricSurface) = PTrianglesOfSurface(self.values)

# ? ---------------------------------
# ! ParametricSurfaceRenderer
# ? ---------------------------------

function ParametricSurface(callback::Function,
                           uRange=range(0.0,1.0,50), vRange=range(0.0,1.0,50),
                           parents::Union{Vector{NodeHandle},Nothing}=nothing, color_data::Union{Nothing,String}=nothing;
                           color="g")::NodeHandle
    c = isnothing(color_data) ? get_color(color) : get_color(color_data)
    return add_node!(callback, ParametricSurface(uRange, vRange); draw_data=ParametricSurfaceDrawData(UInt32(0), c), parents=parents)
end

macro ParametricSurface(callback::Expr,uRange,vRange,args...)
    (positional_args, kw_args) = _parse_macro_arguments((:color_data,),(:color,), args...)
    callback = _validate_callback_expr(callback, 2)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.ParametricSurface,
                                positional_args,kw_args,
                                (cb, deps) -> (cb, uRange, vRange, deps))
end

export ParametricSurface
export @ParametricSurface