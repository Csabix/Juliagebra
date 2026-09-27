mutable struct ParametricCurve
    range::AbstractRange{Float64}
    values::Vector{Vec3D}
    param_tess_data::ParamTessData

    function ParametricCurve(range::AbstractRange{Float64}, param_tess_data::ParamTessData)
        values = Vector{Vec3D}(undef, length(range))
        new(range, values, param_tess_data)
    end
end

struct ParametricCurveDrawData
    handle::UInt32
    colors::Vector{UInt32}
    style::UInt8
    size::Float32
end

const GPU_TESS_CURVE_T_RANGE = :JG_TESS_T_RANGE
const GPU_TESS_CURVE_NODE_UNIFORMS = Dict{Symbol,DataType}(GPU_TESS_CURVE_T_RANGE => Vec2F)

# convert_callback_entry(pc::ParametricCurve)::Vector{Vec3D} = pc.values
convert_callback_entry(self::ParametricCurve)::ParametricCurve = self

function convert_result!(pc::ParametricCurve,v,index)
    if length(v) == 3
        pc.values[index] = Vec3D(v[1],v[2],v[3])
    else
        pc.values[index] = Vec3D(v[1],v[2],0.0)
    end
end
convert_result!(pc::ParametricCurve,v::Tuple{Any,Any},index)     = pc.values[index] = Vec3D(v[1],v[2],0.0)
convert_result!(pc::ParametricCurve,v::Tuple{Any,Any,Any},index) = pc.values[index] = Vec3D(v[1],v[2],v[3])
convert_result!(pc::ParametricCurve,v::Vec3D,index)              = pc.values[index] = v
convert_result!(pc::ParametricCurve,v::Vec3F,index)              = pc.values[index] = Vec3D(v)
convert_result!(pc::ParametricCurve,v::Vec2D,index)              = pc.values[index] = Vec3D(v[1],v[2],0.0)
convert_result!(pc::ParametricCurve,v::Vec2F,index)              = pc.values[index] = Vec3D(v[1],v[2],0.0)
convert_result!(pc::ParametricCurve,v::Nothing,index)            = pc.values[index] = Vec3DNan

eval_geometry_node(element::ParametricCurve, node::GeometryPlotNode, elements::Vector{Any}) =
    handle_param_tess!(element.param_tess_data, element, node, elements; pos_buffer_read=true, pos_buffer_write=false)

function eval_node(element::ParametricCurve, callback::Function, arguments::Vector{Any})::Any
    for index in eachindex(element.range)
        convert_result!(element,callback(element.range[index],arguments...),index)
    end
    return element
end

function update_node_uniforms!(uniform_values::Dict{Symbol,Any}, element::ParametricCurve)
    uniform_values[GPU_TESS_CURVE_T_RANGE] = Vec2F(first(element.range), step(element.range))
end

function convert_gpu_result(element::ParametricCurve,pos_buffer::MappedBuffer{Vec4})::Tuple{Bool,Any}
    @inbounds for (index, v4) in enumerate(pos_buffer._mapped)
        convert_result!(element,v4.xyz,index)
    end

    return (true, element)
end

function render_node(pc::ParametricCurve, data::ParametricCurveDrawData, renderers::Dict{DataType,Renderer}, id::UInt32)::ParametricCurveDrawData
    @time_cpu_begin ParamTess Render Curve
    line_renderer::LineRenderer = renderers[LineRenderer]
    if data.handle == 0
        handle = add!(line_renderer, pc.values, Iterators.cycle(data.colors), Iterators.cycle(id), data.size, data.style)
        @time_cpu_end ParamTess Render Curve
        return ParametricCurveDrawData(handle, data.colors, data.style, data.size)
    else
        update_coords!(line_renderer, data.handle, pc.values)
        @time_cpu_end ParamTess Render Curve
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

function wrap_curve_callback(callback_ast::Expr)::Union{Expr,Nothing}
    dbg::Bool = (GPU_TESS_DEBUG_ARG in ARGS)

    if !_is_normalized_callback(callback_ast)
        dbg && @log "Cannot transpile callback AST that has not been normalized"
        return nothing
    end

    if isempty(callback_ast.args[1].args)
        dbg && @log "Cannot transpile zero-argument callback as a curve"
        return nothing
    end

    result = deepcopy(callback_ast)

    t_varname = result.args[1].args[1]
    popfirst!(result.args[1].args)

    pushfirst!(result.args[2].args, :(
        $t_varname = $(GPU_TESS_CURVE_T_RANGE).x + Float32(JG_TESS_ID) * $(GPU_TESS_CURVE_T_RANGE).y
    ))

    return result
end

edit_node_overload(::ParametricCurve)::Bool = true
function edit_node(pc::ParametricCurve,data::ParametricCurveDrawData,renderers::Dict{DataType,Renderer},handle::NodeHandle)::Tuple{Any,Any,Int}
    result = EDIT_NODE_NONE

    CImGui.Text("Tessellation Mode: $(pc.param_tess_data.current_mode)")

    CImGui.SameLine()
    if CImGui.Button("-> CPU")
        pc.param_tess_data.next_mode = ParamTessMode.CPU
        result |= EDIT_NODE_INVALIDATE
    end
    
    CImGui.SameLine()
    if CImGui.Button("-> GPU")
        pc.param_tess_data.next_mode = ParamTessMode.GPU
        result |= EDIT_NODE_INVALIDATE
    end
    
    return pc, data, result
end

function ParametricCurve(callback::Function, range::AbstractRange{Float64},
                parents::Union{Vector{NodeHandle},Nothing}=nothing, color_style::Union{Nothing,String}=nothing;
                color="c", style="-", size=5.0f0, callback_ast::Union{Expr,Nothing}=nothing,
                argument_bindings::Union{Dict{Symbol,NodeHandle},Nothing}=nothing,
                enable_gpu_tessellation::Bool=false)::NodeHandle
    (c, s) = parse_line_colors_style(color_style, color, style)
    draw_data = ParametricCurveDrawData(UInt32(0), c, s, Float32(size))
    
    if !enable_gpu_tessellation
        callback_ast = nothing
        argument_bindings = nothing
    elseif callback_ast !== nothing
        callback_ast = wrap_curve_callback(callback_ast)
    end
    n = length(range)
    param_tess_data = (callback_ast !== nothing && argument_bindings !== nothing) ?
        ParamTessData(callback_ast, argument_bindings, GPU_TESS_CURVE_NODE_UNIFORMS, n) :
        ParamTessData(n)

    # TODO: unpin main thread requirement dynamically
    # currently pins main thread when there's any possibility GPU tessellation will be possible
    return add_node!(callback, ParametricCurve(range,param_tess_data); draw_data=draw_data, parents=parents,
                     use_main_thread=(param_tess_data.transpilation_src !== nothing))
end

macro ParametricCurve(callback::Expr,range,args...)
    (positional_args, kw_args) = _parse_macro_arguments((:color_style,),(:color, :style, :size, :enable_gpu_tessellation), args...)
    callback = _validate_callback_expr(callback, 1)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.ParametricCurve,
                                positional_args, kw_args, (cb, deps) -> (cb, range, deps), true)
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

    return ParametricCurve(callback, range(get_domain_start(func_node),get_domain_end(func_node),resolution), [func_handle],
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

    return ParametricCurve(range(get_domain_start(func_node),get_domain_end(func_node),resolution), parents,
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

        curve.derivative_1st = Func(curve_func.domain, [curve.func]) do t,func
            t = clamp(t, get_domain_start(func) + calc_h(t), get_domain_end(func) - calc_h(t))
            return derive_num(func, t)
        end
    end

    return curve.derivative_1st
end
function get_derived2nd_handle(curve::Curve)
    if (curve.derivative_2nd === nothing)
        curve_func = get_element(curve.func)

        curve.derivative_2nd = Func(curve_func.domain, [curve.func]) do t,func
            t = clamp(t, get_domain_start(func) + calc_h_large(t), get_domain_end(func) - calc_h_large(t))
            return derive2nd_num(func, t)
        end
    end

    return curve.derivative_2nd
end
function get_curvature_handle(curve::Curve)
    if (curve.curvature === nothing)
        derived_handle = get_derived_handle(curve)
        derived2nd_handle = get_derived2nd_handle(curve)
        func::Func = get_element(derived_handle)

        curvature_callback = if (func.output_count == 1)
            (t,derive,derive2nd) -> begin
                return derive2nd(t) / (1 + derive(t)^2)^(3/2)
            end
        elseif (func.output_count == 2)
            (t,derive,derive2nd) -> begin
                d1 = derive(t)
                d2 = derive2nd(t)
                return zcross(d1,d2) / norm(d1)^3
            end
        else
            (t,derive,derive2nd) -> begin
                d1 = derive(t)
                d2 = derive2nd(t)
                return norm(cross(d1,d2)) / norm(d1)
            end
        end

        curve.curvature = Func(curvature_callback, func.domain, [derived_handle,derived2nd_handle])
    end

    return curve.curvature
end
function get_arc_length_handle(curve::Curve)
    if (curve.arc_length === nothing)
        derived_handle = get_derived_handle(curve)
        func::Func = get_element(derived_handle)

        a = get_domain_start(func)
        b = get_domain_end(func)
        distance_callback = if (func.output_count == 1)
            (derive,t) -> sqrt(1 + derive(t)^2)
        else
            (derive,t) -> norm(derive(t))
        end

        curve.arc_length = Scalar([derived_handle]; label="Arc-length") do derive
            sum = 0
            for t in range(a,b,INTEGRAL_RES)
                sum += distance_callback(derive,t)
            end

            delta = (b - a) / INTEGRAL_RES
            return sum * delta
        end
    end
    
    return curve.arc_length
end
function get_frenet_frame_handle(curve::Curve)
    if (curve.frenet_frame === nothing)
        derived_handle = get_derived_handle(curve)
        derived2nd_handle = get_derived2nd_handle(curve)
        func::Func = get_element(derived_handle)

        curve.frenet_frame = Func(func.domain,
            [derived_handle,derived2nd_handle]) do t,derive,derive2nd

            T = normalize(derive(t))
            B = normalize(cross(derive(t),derive2nd(t)))
            N = cross(T,B)

            return hcat(T,N,B)
        end
    end

    return curve.frenet_frame
end

T(frame::SMatrix)::Vec3D = Vec3D(frame[:,1])
N(frame::SMatrix)::Vec3D = Vec3D(frame[:,2])
B(frame::SMatrix)::Vec3D = Vec3D(frame[:,3])
export T,N,B

function Curve!(curve_func_handle::NodeHandle, derivative_1st_handle::Union{NodeHandle,Nothing}=nothing, derivative_2nd_handle::Union{NodeHandle,Nothing}=nothing;
    parametric_curve::Bool=false, color_style::Union{Nothing,String}=nothing, resolution::Int=100, color="c", style="-", size=5.0f0)

    if (parametric_curve)
        parametric_curve_handle = ParametricCurve(curve_func_handle,color_style;resolution=resolution,color=color,style=style,size=size)
    end
    curve = Curve(curve_func_handle,derivative_1st_handle,derivative_2nd_handle)
    curve_handle = add_node!(curve)

    return parametric_curve ? (curve_handle,parametric_curve_handle) : curve_handle
end



export Curve!
