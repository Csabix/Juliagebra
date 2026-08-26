
struct Func
    callback::Function
    domain::Vector{Tuple{Float64,Float64}}
    input_count::Int
    output_count::Int
    parents::Vector{NodeHandle}
    function Func(callback::Function,domain::Vector{Tuple{Float64,Float64}},output_count::Int,parents::Vector{NodeHandle})
        new(callback,domain,length(domain),output_count,parents)
    end
end

struct FuncDrawData
    graph_resolution::Int
    graph_colors::Union{ImPlot.ImPlotColormap_,String}
end

# convert_callback_entry(func::Func)::Function = func.callback
convert_callback_entry(func::Func) = func
convert_callback_result(func::Func, ::Any) = func

edit_node_overload(func::Func)::Bool = true
function edit_node(func::Func,data::Any,::Dict{DataType,Renderer},::NodeHandle)::Tuple{Any,Any,Int}

    if (data === nothing) return (func,data,EDIT_NODE_NONE) end

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

get_func_parents(parents) = [convert_callback_entry(get_element(handle)) for handle in parents]
evaluate(func::Func, args...) = func.callback(args..., get_func_parents(func.parents)...)
export evaluate

# ? ---------------------------------
# ! Func constructors
# ? ---------------------------------

const FUNC_GRAPH_RESOLUTION::Int = 1000
const FUNC_HEATMAP_RESOLUTION::Int = 100

function CreateFunction(callback::Function,inputs::Vector{Tuple{<:T,<:S}},parents::Vector{NodeHandle}=NodeHandle[];
    output_count::Union{Int,Nothing}=nothing) where {T<:Real,S<:Real}

    inputs = [(Float64(input[1]),Float64(input[2])) for input in inputs]
    if (output_count === nothing)
        default_values = [(a + b) / 2.0 for (a,b) in inputs]
        default_result = callback(default_values..., get_func_parents(parents)...)
        output_count = length(default_result)
    end

    func = Func(callback,inputs,output_count,parents)

    draw_data = FuncDrawData(FUNC_GRAPH_RESOLUTION,ImPlotColormap_Juliagebra)
    if (func.input_count == 2 && func.output_count == 1)
        draw_data = FuncDrawData(FUNC_HEATMAP_RESOLUTION,ImPlot.ImPlotColormap_Spectral)
    end

    return add_node!(func; draw_data=draw_data, parents=parents)
end



export CreateFunction#, Curve
