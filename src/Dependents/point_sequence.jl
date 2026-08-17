mutable struct PointSequence
    coords::Vector{Vec3D}

    function PointSequence()
        new(Vector{Vec3D}())
    end
end

struct PointSequenceDrawData
    handle::UInt32
    color::UInt32
    style::UInt8
    size::UInt8
end

convert_callback_entry(ps::PointSequence)::Vector{Vec3D} = ps.coords

convert_callback_result(ps::PointSequence,coords::Vector{Vec3D})   = (ps.coords = coords;ps)
convert_callback_result(ps::PointSequence,coords::Vector{Vec3F})   = (ps.coords = Vec3D.(coords);ps)
convert_callback_result(ps::PointSequence,coords::Vector{<:Tuple}) = (ps.coords = [Vec3D(coord...) for coord in coords];ps)
convert_callback_result(ps::PointSequence,coords::Vector{<:AbstractVector}) = (ps.coords = [Vec3D(coord...) for coord in coords];ps)
convert_callback_result(ps::PointSequence,::Nothing) = (ps.coords = Vec3D[];ps)

function render_node(ps::PointSequence, data::PointSequenceDrawData, renderers::Dict{DataType,Renderer}, id::UInt32)::PointSequenceDrawData
    point_renderer::PointRenderer = renderers[PointRenderer]
    if data.handle == 0
        handle = add_dynamic!(point_renderer,
            (Vec3F(coord) for coord in ps.coords),
            Iterators.cycle([data.color]),
            Iterators.cycle([data.style]),
            Iterators.cycle([UInt8(data.size)]),
            Iterators.cycle([id]))
        return PointSequenceDrawData(handle, data.color, data.style, data.size)
    else
        update_dyncamic!(point_renderer, data.handle,
            (Vec3F(coord) for coord in ps.coords),
            Iterators.cycle([data.color]),
            Iterators.cycle([data.style]),
            Iterators.cycle([UInt8(data.size)]),
            Iterators.cycle([id]))
        return data
    end
end

function PointSequence(callback::Function, parents::Union{Vector{NodeHandle},Nothing}=nothing, color_style::Union{Nothing,String}=nothing;
    color="m", style=".", size=25)::NodeHandle
    (c, s) = parse_point_color_style(color_style, color, style)
    draw_data = PointSequenceDrawData(UInt32(0), c, s, round(UInt8, size))
    return add_node!(callback, PointSequence(); draw_data=draw_data, parents=parents)
end

PointSequence(parents::Vector{NodeHandle},color_style::Union{Nothing,String}=nothing;
    color="m",style=".",size=25)::NodeHandle =
PointSequence(_deps_collect,parents,color_style;color=color,style=style,size=size)

macro PointSequence(callback::Expr, args...)
    (positional_args, kw_args) = _parse_macro_arguments((:color_style,),(:color, :style, :size), args...)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.PointSequence,
                                positional_args, kw_args)
end

export PointSequence
export @PointSequence