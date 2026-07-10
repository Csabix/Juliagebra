mutable struct PointSequence
    coords::Vector{Vec3D}
    handle::UInt32
    color::UInt32
    style::UInt8
    size::UInt8

    function PointSequence(color::UInt32,style::UInt8,size::UInt8)
        new(Vector{Vec3D}(),UInt32(0),color,style,size)
    end
end

convert_callback_entry(ps::PointSequence)::Vector{Vec3D} = ps.coords

convert_callback_result(ps::PointSequence,coords::Vector{Vec3D})   = (ps.coords = coords;ps)
convert_callback_result(ps::PointSequence,coords::Vector{Vec3F})   = (ps.coords = Vec3D.(coords);ps)
convert_callback_result(ps::PointSequence,coords::Vector{<:Tuple}) = (ps.coords = [Vec3D(coord...) for coord in coords];ps)
convert_callback_result(ps::PointSequence,coords::Vector{<:AbstractVector}) = (ps.coords = [Vec3D(coord...) for coord in coords];ps)
convert_callback_result(ps::PointSequence,::Nothing) = (ps.coords = Vec3D[];ps)

function render_node(ps::PointSequence, renderers::Dict{DataType,Renderer}, id::UInt32)::Nothing
    point_renderer::PointRenderer = renderers[PointRenderer]
    if ps.handle == 0
        ps.handle = add_dynamic!(point_renderer,
            (Vec3F(coord) for coord in ps.coords),
            Iterators.cycle([ps.color]),
            Iterators.cycle([ps.style]),
            Iterators.cycle([UInt8(ps.size)]),
            Iterators.cycle([id]))
    else
        update_dyncamic!(point_renderer,ps.handle,
            (Vec3F(coord) for coord in ps.coords),
            Iterators.cycle([ps.color]),
            Iterators.cycle([ps.style]),
            Iterators.cycle([UInt8(ps.size)]),
            Iterators.cycle([id]))
    end
    return nothing
end

function PointSequence(callback::Function,parents::Union{Vector{NodeHandle},Nothing}=nothing,color_style::Union{Nothing,String}=nothing;
    color="m",style=".",size=25)::NodeHandle
    (c,s) = parse_point_color_style(color_style,color,style)
    return add_node!(callback,PointSequence(c,s,round(UInt8,size)),parents)
end

PointSequence(parents::Union{Vector{NodeHandle},Nothing}=nothing,color_style::Union{Nothing,String}=nothing;
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