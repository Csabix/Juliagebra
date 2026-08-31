mutable struct ParametricCurve
    range::AbstractRange{Float64}
    values::Vector{Vec3D}

    function ParametricCurve(range::AbstractRange{Float64})
        values = Vector{Vec3D}(undef, length(range))
        new(range, values)
    end
end

struct ParametricCurveDrawData
    handle::UInt32
    colors::Vector{UInt32}
    style::UInt8
    size::Float32
end

# convert_callback_entry(pc::ParametricCurve)::Vector{Vec3D} = pc.values
convert_callback_entry(self::ParametricCurve)::ParametricCurve = self

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

function render_node(pc::ParametricCurve, data::ParametricCurveDrawData, renderers::Dict{DataType,Renderer}, id::UInt32)::ParametricCurveDrawData
    line_renderer::LineRenderer = renderers[LineRenderer]
    if data.handle == 0
        handle = add!(line_renderer, pc.values, Iterators.cycle(data.colors), Iterators.cycle(id), data.size, data.style)
        return ParametricCurveDrawData(handle, data.colors, data.style, data.size)
    else
        update_coords!(line_renderer, data.handle, pc.values)
        return data
    end
end

# ? For Intersectable ParametricCurves.
struct PSegmentsOfCurve <: PrimitivesOf{PSegment}
    _curve::ParametricCurve
end
PrimitivesOf(self::ParametricCurve) = return PSegmentsOfCurve(self)

Base.length(self::PSegmentsOfCurve) = (max(length(self._curve.range) - 1,0))

function Base.getindex(self::PSegmentsOfCurve, index::Integer)::Union{Nothing, PSegment}
    if ((1 <= index) && (index <= length(self)))
        return PSegment(self._curve.values[index], self._curve.values[index + 1])
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

function ParametricCurve(callback::Function, range::AbstractRange{Float64},
                parents::Union{Vector{NodeHandle},Nothing}=nothing, color_style::Union{Nothing,String}=nothing;
                color="c", style="-", size=5.0f0)::NodeHandle
    (c, s) = parse_line_colors_style(color_style, color, style)
    draw_data = ParametricCurveDrawData(UInt32(0), c, s, Float32(size))
    return add_node!(callback, ParametricCurve(range); draw_data=draw_data, parents=parents)
end

macro ParametricCurve(callback::Expr,range,args...)
    (positional_args, kw_args) = _parse_macro_arguments((:color_style,),(:color, :style, :size), args...)
    callback = _validate_callback_expr(callback, 1)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.ParametricCurve,
                                positional_args, kw_args, (cb, deps) -> (cb, range, deps))
end

function ParametricCurve(func_handle::NodeHandle,
    color_style::Union{Nothing,String}=nothing; resolution::Int=100, color="c", style="-", size=5.0f0)::NodeHandle

    func_node = get_element(func_handle)
    if (isa(func_node, Curve))
        func_handle = func_node.func
        func_node = get_element(func_handle)
    end

    callback = if (func_node.input_count == 1 && func_node.output_count == 1)
        (t,func) -> Vec3D(t,func(t),0)
    elseif (func_node.input_count == 1 && func_node.output_count == 2)
        (t,func) -> Vec3D(func(t)...,0)
    else
        (t,func) -> func(t)
    end

    return ParametricCurve(callback, range(func_node.domain[1][1],func_node.domain[1][2],resolution), [func_handle],
        color_style; color=color, style=style, size=size)
end
function ParametricCurve(callback::Function, func_handle::NodeHandle, parents::Union{Vector{NodeHandle},Nothing}=nothing,
    color_style::Union{Nothing,String}=nothing; resolution::Int=100, color="c", style="-", size=5.0f0)::NodeHandle

    func_node = get_element(func_handle)
    if (isa(func_node, Curve))
        func_handle = func_node.func
        func_node = get_element(func_handle)
    end
    parents = parents === nothing ? [func_handle] : [func_handle, parents...]

    return ParametricCurve(range(func_node.domain[1][1],func_node.domain[1][2],resolution), parents,
        color_style; color=color, style=style, size=size) do t,func,args...
        return callback(t,func,args...)
    end
end
function ParametricCurve(callback::Function, inputs::Union{Tuple{<:T,<:S},Vector{Tuple{<:T,<:S}}}, parents::Union{Vector{NodeHandle},Nothing}=nothing,
    color_style::Union{Nothing,String}=nothing; resolution::Int=100, color="c", style="-", size=5.0f0, node::Bool=true, func::Bool=false,
    output_count::Union{Int,Nothing}=nothing) where {T<:Real,S<:Real}

    (func_node, func_draw_data) = _create_func(callback,inputs, parents; output_count=output_count)
    func_handle = _create_func_node(func_node, func_draw_data, parents)

    parametric_curve = ParametricCurve(func_handle, color_style; color=color ,style=style, size=size, resolution=resolution)

    result = Any[]
    if (node)
        push!(result, parametric_curve)
    end
    if (func)
        push!(result, func_handle)
    end

    return length(result) == 1 ? result[1] : Tuple(result)
end

export ParametricCurve
export @ParametricCurve

# ? ---------------------------------
# ! Curve node
# ? ---------------------------------

mutable struct Curve
    func::NodeHandle
    derivative_1st::Union{NodeHandle,Nothing}
    derivative_2nd::Union{NodeHandle,Nothing}
    curvature::Union{NodeHandle,Nothing}
    arc_length::Union{NodeHandle,Nothing}
    frenet_frame::Union{NodeHandle,Nothing}

    function Curve(func::NodeHandle,derivative_1st::Union{NodeHandle,Nothing},derivative_2nd::Union{NodeHandle,Nothing})
        new(func,derivative_1st,derivative_2nd,nothing,nothing,nothing)
    end
end

function get_derived_handle(curve::Curve)
    if (curve.derivative_1st === nothing)
        curve_func = get_element(curve.func)
        derivative_1st_handle = Func(curve_func.domain, [curve.func]) do t,func
            t = clamp(t, func.domain[1][1] + DIFF_H, func.domain[1][2] - DIFF_H)
            return derive_num(func, t)
        end
        curve.derivative_1st = derivative_1st_handle
    end

    return curve.derivative_1st
end
function get_derived2nd_handle(curve::Curve)
    if (curve.derivative_2nd === nothing)
        curve_func = get_element(curve.func)
        derivative_2nd_handle = Func(curve_func.domain, [curve.func]) do t,func
            t = clamp(t, func.domain[1][1] + DIFF_H, func.domain[1][2] - DIFF_H)
            return derive2nd_num(func, t)
        end
        curve.derivative_2nd = derivative_2nd_handle
    end

    return curve.derivative_2nd
end
function get_curvature_handle(curve::Curve)
    if (curve.curvature === nothing)
        derived_handle = get_derived_handle(curve)
        derived2nd_handle = get_derived2nd_handle(curve)
        curve_func::Func = get_element(curve.func)
        curvature_handle = Func(curve_func.domain, [derived_handle,derived2nd_handle]) do t,derive,derive2nd
            return derive2nd(t) ./ (1 .+ derive(t).^2).^(3/2)
        end
        curve.curvature = curvature_handle
    end

    return curve.curvature
end
function get_arc_length_handle(curve::Curve)
    if (curve.arc_length === nothing)
        derived_handle = get_derived_handle(curve)
        arc_length_handle = Scalar([curve.func,derived_handle]; label="Arc-length") do func,derive
            if (func.output_count == 1)
                distance = t -> sqrt(1 + derive(t)^2)
            else
                distance = t -> norm(derive(t))
            end

            a = func.domain[1][1]
            b = func.domain[1][2]
            sum = 0
            for t in range(a,b,10_000)
                sum += distance(t)
            end

            delta = (abs(a) + abs(b)) / 10_000
            return sum * delta
        end
        curve.arc_length = arc_length_handle
    end
    
    return curve.arc_length
end
function get_frenet_frame_handle(curve::Curve)
    if (curve.frenet_frame === nothing)
        derived_handle = get_derived_handle(curve)
        derived2nd_handle = get_derived2nd_handle(curve)
        arc_length_handle = get_arc_length_handle(curve)
        curve_func::Func = get_element(curve.func)
        frenet_frame_handle = Func(curve_func.domain,
            [derived_handle,derived2nd_handle,arc_length_handle]) do t,derive,derive2nd,arc_length

            T = normalize(derive(t))
            N = normalize(derive2nd(t) / arc_length)
            B = normalize(cross(T,N))

            return hcat(T,N,B)
        end

        curve.frenet_frame = frenet_frame_handle
    end

    return curve.frenet_frame
end

T(frame::SMatrix)::Vec3D = Vec3D(frame[:,1])
N(frame::SMatrix)::Vec3D = Vec3D(frame[:,2])
B(frame::SMatrix)::Vec3D = Vec3D(frame[:,3])
export T,N,B

function Curve!(curve_func_handle::NodeHandle, derivative_1st_handle::Union{NodeHandle,Nothing}=nothing, derivative_2nd_handle::Union{NodeHandle,Nothing}=nothing)

    curve = Curve(curve_func_handle,derivative_1st_handle,derivative_2nd_handle)

    return add_node!(curve)
end



export Curve!
