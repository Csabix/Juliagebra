mutable struct ParametricCurve
    range::AbstractRange{Float64}
    values::Vector{Vec3D}
    colors::Vector{UInt32}
    size::Float32
    style::UInt8
    handle::UInt32

    function ParametricCurve(range::AbstractRange{Float64},color::Vector{UInt32},style::UInt8,size::Float32)
        values = Vector{Vec3D}(undef,length(range))
        new(range,values,color,size,style,UInt32(0))
    end
end

convert_callback_entry(pc::ParametricCurve)::Vector{Vec3D} = pc.values

function convert_result(pc::ParametricCurve,v,index)
    if length(v) == 3
        pc.values[index] = Vec3D(v[1],v[2],v[3])
    else
        pc.values[index] = Vec3D(v[1],v[2],0.0)
    end
end
convert_result(pc::ParametricCurve,v::Tuple{Any,Any},index)     = pc.values[index] = Vec3D(v[1],v[2],0.0)
convert_result(pc::ParametricCurve,v::Tuple{Any,Any,Any},index) = pc.values[index] = Vec3D(v[1],v[2],v[3])
convert_result(pc::ParametricCurve,v::Vec3D,index)              = pc.values[index] = v
convert_result(pc::ParametricCurve,v::Vec3F,index)              = pc.values[index] = Vec3D(v)
convert_result(pc::ParametricCurve,v::Vec2D,index)              = pc.values[index] = Vec3D(v[1],v[2],0.0)
convert_result(pc::ParametricCurve,v::Vec2F,index)              = pc.values[index] = Vec3D(v[1],v[2],0.0)
convert_result(pc::ParametricCurve,v::Nothing,index)            = pc.values[index] = Vec3DNan

function eval_node(element::ParametricCurve, callback::Function, arguments::Vector{Any})::Any
    for index in eachindex(element.range)
        convert_result(element,callback(element.range[index],arguments...),index)
    end
    return element
end

function render_node(pc::ParametricCurve, renderers::Dict{DataType,Renderer}, id::UInt32)::Nothing
    line_renderer::LineRenderer = renderers[LineRenderer]
    if pc.handle == 0
        pc.handle = add!(line_renderer,pc.values,Iterators.cycle(pc.colors),Iterators.cycle(id),pc.size,pc.style)
    else
        update_coords!(line_renderer,pc.handle,pc.values)
    end
    return nothing
end

# ? For Intersectable ParametricCurves.
struct PSegmentsOfCurve <: PrimitivesOf{PSegment}
    _curve::ParametricCurve
end
PrimitivesOf(self::ParametricCurve) = return PSegmentsOfCurve(self)

Base.length(self::PSegmentsOfCurve) = (max(length(self._curve._range) - 1,0))

function Base.getindex(self::PSegmentsOfCurve, index::Integer)::Union{Nothing, PSegment}
    if ((1 <= index) && (index <= length(self)))
        return PSegment(self._curve._tValues[index], self._curve._tValues[index + 1])
    else
        return nothing 
    end
end

function Base.iterate(self::PSegmentsOfCurve, index::Integer = 1)
    if ((1 <= index) && (index <= length(self)))
        return (self[index], (index + 1))
    else
        return nothing
    end
end

function ParametricCurve(callback::Function,range::AbstractRange{Float64},
                parents::Union{Vector{NodeHandle},Nothing}=nothing,color_style::Union{Nothing,String}=nothing;
                color="c",style="-",size=5.0f0)::NodeHandle
    (c,s) = parse_line_colors_style(color_style,color,style)
    return add_node!(callback,ParametricCurve(range,c,s,Float32(size)),parents)
end

macro ParametricCurve(callback::Expr,range,args...)
    (positional_args, kw_args) = _parse_macro_arguments((:color_style,),(:color, :style, :size), args...)
    callback = _validate_callback_expr(callback, 1)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.ParametricCurve,
                                positional_args, kw_args, (cb, deps) -> (cb, range, deps))
end

export ParametricCurve
export @ParametricCurve
