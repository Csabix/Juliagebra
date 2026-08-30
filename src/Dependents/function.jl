
# ? ---------------------------------
# ! Func node
# ? ---------------------------------

mutable struct Func{outT,Storage}
    callback::Function
    domain::Vector{Tuple{Float64,Float64}}
    input_count::Int
    output_count::Int
    parents::Vector{NodeHandle}

    value_changed::Bool
    values::Union{Storage,Nothing}

    function Func{T}(callback::Function,domain::Vector{Tuple{Float64,Float64}},output_count::Int,parents::Vector{NodeHandle}) where T
        dimension = length(domain)
        new{T,Array{T,dimension}}(callback,domain,dimension,output_count,parents,true,nothing)
    end
end

abstract type GraphDrawData end
struct FuncDrawData <: GraphDrawData
    graph_resolution::Int
    graph_colors::Union{ImPlot.ImPlotColormap_,String}
end

struct CallableFunc
    callback::Function
    domain::Vector{Tuple{Float64,Float64}}
    input_count::Int
    output_count::Int

    function CallableFunc(func::Func)
        new((args...) -> evaluate(func, args...),func.domain,func.input_count,func.output_count)
    end
end

(callable_func::CallableFunc)(args...) = callable_func.callback(args...)

convert_callback_entry(func::Func)::CallableFunc = CallableFunc(func)
convert_callback_result(func::Func, ::Any) = func

function eval_node(element::Func, callback::Function, ::Vector{Any})::Any
    callback(element)
    return element
end

edit_node_overload(::Func{T}) where T = _can_be_graphed(T)::Bool
edit_node_name(::Func)::String = "Function"
function edit_node(func::Func,data::GraphDrawData,::Dict{DataType,Renderer},::NodeHandle)::Tuple{Any,Any,Int}

    if (func.input_count == 1 && func.output_count > 0)

        domain_start = func.domain[1][1]
        domain_end = func.domain[1][2]
        xs = collect(range(domain_start,domain_end,data.graph_resolution))
        if (func.value_changed)
            _calc_graph_values!(func,data)
        end
        min_y = minimum(Iterators.flatten(func.values))
        max_y = maximum(Iterators.flatten(func.values))

        ImPlot.SetNextAxesLimits(domain_start,domain_end,min_y,max_y,CImGui.ImGuiCond_Once)
        if (ImPlot.BeginPlot(_get_func_label(func), "x", "y"))
            ImPlot.PushColormap(data.graph_colors)
            for n in 1:func.output_count
                ImPlot.PlotLine(func.output_count == 1 ? "f(x)" : "f(x)[$n]", xs, [y[n] for y in func.values])
            end
            ImPlot.EndPlot()
        end
    elseif (func.input_count == 2 && func.output_count == 1)

        domain_start_u = func.domain[1][1]
        domain_end_u = func.domain[1][2]
        domain_start_v = func.domain[2][1]
        domain_end_v = func.domain[2][2]
        if (func.value_changed)
            _calc_graph_values!(func,data)
        end

        ImPlot.SetNextAxesLimits(domain_start_u,domain_end_u,domain_start_v,domain_end_v,CImGui.ImGuiCond_Once)
        if (ImPlot.BeginPlot(_get_func_label(func), "u", "v"))
            ImPlot.PushColormap(data.graph_colors)
            ImPlot.PlotHeatmap("f(u,v)", func.values, data.graph_resolution, data.graph_resolution;
                label_fmt="", bounds_min=ImPlotPoint(domain_start_u,domain_start_v), bounds_max=ImPlotPoint(domain_end_u,domain_end_v))
            ImPlot.EndPlot()
        end
    end

    return (func,data,EDIT_NODE_NONE)
end

function _get_func_label(func::Func)::String
    if (func.input_count == 1)
        if (func.output_count == 1)
            "f:R->R"
        else
            "f:R->R^$(func.output_count)"
        end
    elseif (func.input_count > 1)
        if (func.output_count == 1)
            "f:R^$(func.input_count)->R"
        else
            "f:R^$(func.input_count)->R^$(func.output_count)"
        end
    else
        return "function"
    end
end

function _calc_graph_values!(func::Func,data::GraphDrawData)
    if (func.input_count == 1 && func.output_count > 0)
        domain_start = func.domain[1][1]
        domain_end = func.domain[1][2]
        xs = collect(range(domain_start,domain_end,data.graph_resolution))
        func.values = [@invokelatest evaluate(func,t) for t in xs]
    elseif (func.input_count == 2 && func.output_count == 1)
        domain_start_u = func.domain[1][1]
        domain_end_u = func.domain[1][2]
        domain_start_v = func.domain[2][1]
        domain_end_v = func.domain[2][2]
        xs = collect(range(domain_start_u,domain_end_u,data.graph_resolution))
        ys = collect(range(domain_start_v,domain_end_v,data.graph_resolution))
        func.values = [@invokelatest evaluate(func,u,v) for u in xs, v in ys]
    end
    func.value_changed = false
end

_get_func_parents(parents) = [convert_callback_entry(get_element(handle)) for handle in parents]
evaluate(func::Func, args...) = func.callback(args..., _get_func_parents(func.parents)...)

# ? ---------------------------------
# ! Func constructors
# ? ---------------------------------

function (func::Func)(funcHandle::NodeHandle,args...)
    parents = [funcHandle, get_parent_nodes(args...)...]
    if (func.output_count == 1)
        return Scalar((f,nodes...) -> f(nodes...),parents; label="$(_get_func_label(func)) result")
    elseif (func.output_count == 2)
        return Point(parents) do f,nodes...
            result = f(nodes...)
            return (result[1],result[2],0)
        end
    elseif (func.output_count == 3)
        return Point((f,nodes...) -> f(nodes...),parents)
    end
end

const FUNC_GRAPH_RESOLUTION::Int = 1000
const FUNC_HEATMAP_RESOLUTION::Int = 100

_can_be_graphed(type::Type)::Bool = type <: Union{Real,Tuple{Vararg{Real}},Vec3T}

function _create_func(callback::Function,inputs::Union{Tuple{<:T,<:S},Vector{Tuple{<:T,<:S}}},parents::Union{Vector{NodeHandle},Nothing}=nothing;
    output_count::Union{Int,Nothing}=nothing)::Tuple{Func,Union{FuncDrawData,Nothing}} where {T<:Real,S<:Real}

    if (isa(inputs, Tuple)) inputs = [inputs] end
    if (parents === nothing) parents = NodeHandle[] end

    inputs = [(Float64(input[1]),Float64(input[2])) for input in inputs]
    default_values = [(a + b) / 2.0 for (a,b) in inputs]
    default_result = callback(default_values..., _get_func_parents(parents)...)
    outT = typeof(default_result)
    if (output_count === nothing)
        output_count = hasmethod(length, Tuple{outT}) ? length(default_result) : 1
    end

    func = Func{outT}(callback,inputs,output_count,parents)

    draw_data = nothing
    if (_can_be_graphed(outT))
        if (func.input_count == 1 && func.output_count > 0)
            draw_data = FuncDrawData(FUNC_GRAPH_RESOLUTION,ImPlotColormap_Juliagebra)
        elseif (func.input_count == 2 && func.output_count == 1)
            draw_data = FuncDrawData(FUNC_HEATMAP_RESOLUTION,ImPlot.ImPlotColormap_Spectral)
        end
    end

    return (func,draw_data)
end
function _create_func_node(func::Func{T},draw_data::Any,parents::Union{Vector{NodeHandle},Nothing}=nothing)::NodeHandle where T

    if (_can_be_graphed(T))
        return add_node!(func; draw_data=draw_data, parents=parents) do self
            self.value_changed = true
        end
    else
        return add_node!(func; draw_data=draw_data, parents=parents)
    end
end

function Func(callback::Function,inputs::Union{Tuple{<:T,<:S},Vector{Tuple{<:T,<:S}}},parents::Union{Vector{NodeHandle},Nothing}=nothing;
    output_count::Union{Int,Nothing}=nothing) where {T<:Real,S<:Real}

    (func,draw_data) = _create_func(callback,inputs,parents;output_count=output_count)

    return add_node!(func; draw_data=draw_data, parents=parents)
end

export Func,CallableFunc
