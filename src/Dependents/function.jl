
# ? ---------------------------------
# ! Func node
# ? ---------------------------------

struct Func
    callback::Function
    domain::Vector{Tuple{Float64,Float64}}
    input_count::Int
    output_count::Int
    output_type::Type
    parents::Vector{NodeHandle}
    
    function Func(callback::Function,domain::Vector{Tuple{Float64,Float64}},output_count::Int,output_type::Type,parents::Vector{NodeHandle})
        new(callback,domain,length(domain),output_count,output_type,parents)
    end
end

abstract type GraphDrawData end
struct FuncDrawData <: GraphDrawData
    graph_resolution::Int
    graph_colors::Union{ImPlot.ImPlotColormap_,String}
end

convert_callback_entry(func::Func) = func
convert_callback_result(func::Func, ::Any) = func

edit_node_overload(func::Func)::Bool = true
function edit_node(func::Func,data::GraphDrawData,::Dict{DataType,Renderer},::NodeHandle)::Tuple{Any,Any,Int}

    if (func.input_count == 1 && func.output_count > 0)

        domain_start = func.domain[1][1]
        domain_end = func.domain[1][2]
        xs = collect(range(domain_start,domain_end,data.graph_resolution))
        ys = [@invokelatest evaluate(func,t) for t in xs]
        min_y = minimum(Iterators.flatten(ys))
        max_y = maximum(Iterators.flatten(ys))

        label = if (func.input_count == 1 && func.output_count == 1)
            "f:R->R"
        else
            "f:R->R^$(func.output_count)"
        end

        ImPlot.SetNextAxesLimits(domain_start,domain_end,min_y,max_y,CImGui.ImGuiCond_Once)
        if (ImPlot.BeginPlot(label, "x", "y"))
            ImPlot.PushColormap(data.graph_colors)
            for n in 1:func.output_count
                ImPlot.PlotLine(func.output_count == 1 ? "f(x)" : "f(x)[$n]", xs, [y[n] for y in ys])
            end
            ImPlot.EndPlot()
        end
    elseif (func.input_count == 2 && func.output_count == 1)

        domain_start_u = func.domain[1][1]
        domain_end_u = func.domain[1][2]
        domain_start_v = func.domain[2][1]
        domain_end_v = func.domain[2][2]
        xs = collect(range(domain_start_u,domain_end_u,data.graph_resolution))
        ys = collect(range(domain_start_v,domain_end_v,data.graph_resolution))
        zs = [@invokelatest evaluate(func,u,v) for u in xs, v in ys]

        ImPlot.SetNextAxesLimits(domain_start_u,domain_end_u,domain_start_v,domain_end_v,CImGui.ImGuiCond_Once)
        if (ImPlot.BeginPlot("f:R^2->R", "u", "v"))
            ImPlot.PushColormap(data.graph_colors)
            ImPlot.PlotHeatmap("f(u,v)", zs, data.graph_resolution, data.graph_resolution;
                label_fmt="", bounds_min=ImPlotPoint(domain_start_u,domain_start_v), bounds_max=ImPlotPoint(domain_end_u,domain_end_v))
            ImPlot.EndPlot()
        end
    end

    return (func,data,EDIT_NODE_NONE)
end

node_called(::Func,::Any,funcHandle::NodeHandle,nodeHandle::NodeHandle) = Scalar((f,n) -> evaluate(f,n),[funcHandle,nodeHandle])

get_func_parents(parents) = [convert_callback_entry(get_element(handle)) for handle in parents]
evaluate(func::Func, args...) = func.callback(args..., get_func_parents(func.parents)...)
export evaluate

# ? ---------------------------------
# ! Func constructors
# ? ---------------------------------

const FUNC_GRAPH_RESOLUTION::Int = 1000
const FUNC_HEATMAP_RESOLUTION::Int = 100

_can_be_graphed(type::Type)::Bool = type <: Union{Real,Tuple{Vararg{Real}},Vec3T}

function _create_func(callback::Function,inputs::Union{Tuple{<:T,<:S},Vector{Tuple{<:T,<:S}}},parents::Vector{NodeHandle}=NodeHandle[];
    output_count::Union{Int,Nothing}=nothing)::Tuple{Func,Union{FuncDrawData,Nothing}} where {T<:Real,S<:Real}

    if (isa(inputs, Tuple)) inputs = [inputs] end
    inputs = [(Float64(input[1]),Float64(input[2])) for input in inputs]
    default_values = [(a + b) / 2.0 for (a,b) in inputs]
    default_result = callback(default_values..., get_func_parents(parents)...)
    outT = typeof(default_result)
    if (output_count === nothing)
        output_count = hasmethod(length, Tuple{outT}) ? length(default_result) : 1
    end

    func = Func(callback,inputs,output_count,outT,parents)

    draw_data = nothing
    if (_can_be_graphed(func.output_type))
        if (func.input_count == 1 && func.output_count > 0)
            draw_data = FuncDrawData(FUNC_GRAPH_RESOLUTION,ImPlotColormap_Juliagebra)
        elseif (func.input_count == 2 && func.output_count == 1)
            draw_data = FuncDrawData(FUNC_HEATMAP_RESOLUTION,ImPlot.ImPlotColormap_Spectral)
        end
    end

    return (func,draw_data)
end

function CreateFunction(callback::Function,inputs::Union{Tuple{<:T,<:S},Vector{Tuple{<:T,<:S}}},parents::Vector{NodeHandle}=NodeHandle[];
    output_count::Union{Int,Nothing}=nothing) where {T<:Real,S<:Real}

    (func,draw_data) = _create_func(callback,inputs,parents;output_count=output_count)

    return add_node!(func; draw_data=draw_data, parents=parents)
end



# TODO: place inside curve.jl

struct CurveDrawData <: GraphDrawData
    graph_resolution::Int
    graph_colors::Union{ImPlot.ImPlotColormap_,String}
    
    handle::UInt32
    colors::Vector{UInt32}
    style::UInt8
    size::Float32
    
    function CurveDrawData(graph_draw_data::GraphDrawData,handle::UInt32,colors::Vector{UInt32},style::UInt8,size::Float32)
        new(graph_draw_data.graph_resolution,graph_draw_data.graph_colors,handle,colors,style,size)
    end
end

function render_node(func::Func, data::CurveDrawData, renderers::Dict{DataType,Renderer}, id::UInt32)::CurveDrawData
    line_renderer::LineRenderer = renderers[LineRenderer]

    values = [@invokelatest evaluate(func, i) for i in range(func.domain[1][1],func.domain[1][2],100)]

    if data.handle == 0
        handle = add!(line_renderer, values, Iterators.cycle(data.colors), Iterators.cycle(id), data.size, data.style)
        return CurveDrawData(FuncDrawData(data.graph_resolution, data.graph_colors), handle, data.colors, data.style, data.size)
    else
        update_coords!(line_renderer, data.handle, values)
        return data
    end
end

function ParametricCurve(callback::Function,inputs::Union{Tuple{<:T,<:S},Vector{Tuple{<:T,<:S}}},parents::Vector{NodeHandle}=NodeHandle[],
    color_style::Union{Nothing,String}=nothing;color="c", style="-", size=5.0f0,
    output_count::Union{Int,Nothing}=nothing) where {T<:Real,S<:Real}

    (func,draw_data) = _create_func(callback,inputs,parents;output_count=output_count)

    (c, s) = parse_line_colors_style(color_style, color, style)
    draw_data = CurveDrawData(draw_data, UInt32(0), c, s, convert(Float32, size))

    return add_node!(func; draw_data=draw_data, parents=parents)
end


export CreateFunction,ParametricCurve
