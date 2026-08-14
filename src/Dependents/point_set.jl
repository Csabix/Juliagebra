mutable struct PointSet
    coords::Vector{Vec3D}

    function PointSet()
        new(Vector{Vec3D}())
    end
end

struct PointSetDrawData
    handle::UInt32
    color::UInt32
    style::UInt8
    size::UInt8
end

convert_callback_entry(ps::PointSet)::Vector{Vec3D} = ps.coords

function convert_callback_result(ps::PointSet,coords::Vector{Vec3D})
    @assert length(ps.coords) == length(coords) || length(ps.coords) == 0
    ps.coords = coords
    return ps
end
convert_callback_result(ps::PointSet,coords::Vector{Vec3F})  = convert_callback_result(ps,Vec3D.(coords))
convert_callback_result(ps::PointSet,coords::Vector{<:Tuple})  = convert_callback_result(ps,[Vec3D(coord...) for coord in coords])
convert_callback_result(ps::PointSet,coords::Vector{<:Vector}) = convert_callback_result(ps,[Vec3D(coord...) for coord in coords])
convert_callback_result(ps::PointSet,::Nothing) = (fill!(ps.coords, Vec3DNan);ps)

function render_node(ps::PointSet, data::PointSetDrawData, renderers::Dict{DataType,Renderer}, id::UInt32)::PointSetDrawData
    point_renderer::PointRenderer = renderers[PointRenderer]
    if data.handle == 0
        handle = add!(point_renderer,
            (Vec3F(coord) for coord in ps.coords),
            Iterators.cycle([data.color]),
            Iterators.cycle([data.style]),
            Iterators.cycle([UInt8(data.size)]),
            Iterators.cycle([id]))
        return PointSetDrawData(handle, data.color, data.style, data.size)
    else
        update_coords!(point_renderer, data.handle, ps.coords)
        return data
    end
end

function PointSet(callback::Function, parents::Union{Vector{NodeHandle},Nothing}=nothing, color_style::Union{Nothing,String}=nothing;
    color="m", style=".", size=25)::NodeHandle
    (c, s) = parse_point_color_style(color_style, color, style)
    draw_data = PointSetDrawData(UInt32(0), c, s, round(UInt8, size))
    return add_node!(callback, PointSet(); draw_data=draw_data, parents=parents)
end

PointSet(parents::Vector{NodeHandle},color_style::Union{Nothing,String}=nothing;
    color="m",style=".",size=25)::NodeHandle =
PointSet(_deps_collect,parents,color_style;color=color,style=style,size=size)

PointSet(positions,color_style::Union{Nothing,String}=nothing;
    color="m",style=".",size=25)::NodeHandle =
add_node!(_deps_collect,Vec3D[];parents=[Point(p[1],p[2],p[3],color_style;color=color,style=style,size=size) for p in positions])

macro PointSet(callback::Expr, args...)
    (positional_args, kw_args) = _parse_macro_arguments((:color_style,),(:color, :style, :size), args...)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.PointSet,
                                positional_args, kw_args)
end

export PointSet
export @PointSet