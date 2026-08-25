
struct Func
    callback::Function
    domain::Vector{Tuple{Float64,Float64}}
    input_count::Integer
    output_count::Integer
    parents::Vector{NodeHandle}
    function Func(callback::Function,domain::Vector{Tuple{Float64,Float64}},output_count::Integer,parents::Vector{NodeHandle})
        new(callback,domain,length(domain),output_count,parents)
    end
end

convert_callback_entry(func::Func)::Function = func.callback
convert_callback_result(func::Func, ::Any) = func

const FUNC_GRAPH_RESOLUTION::Integer = 1000
const FUNC_HEATMAP_RESOLUTION::Integer = 100

edit_node_overload(func::Func)::Bool = true
function edit_node(func::Func,::Any,::Dict{DataType,Renderer},::NodeHandle)::Tuple{Any,Any,Int}

    if (func.input_count == 1 && func.output_count > 0)

        domain_start = func.domain[1][1]
        domain_end = func.domain[1][2]
        xs = collect(range(domain_start,domain_end,FUNC_GRAPH_RESOLUTION))
        ys = [@invokelatest func.callback(t) for t in xs]
        min_y = minimum(Iterators.flatten(ys))
        max_y = maximum(Iterators.flatten(ys))

        label = if (func.input_count == 1 && func.output_count == 1)
            "f:R->R"
        else
            "f:R->R^$(func.output_count)"
        end

        ImPlot.SetNextAxesLimits(domain_start,domain_end,min_y,max_y,CImGui.ImGuiCond_Once)
        if (ImPlot.BeginPlot(label, "x", "y"))
            ImPlot.PushColormap(ImPlotColormap_Juliagebra)
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
        xs = collect(range(domain_start_u,domain_end_u,FUNC_HEATMAP_RESOLUTION))
        ys = collect(range(domain_start_v,domain_end_v,FUNC_HEATMAP_RESOLUTION))
        zs = [@invokelatest func.callback(u,v) for u in xs, v in ys]

        ImPlot.SetNextAxesLimits(domain_start_u,domain_end_u,domain_start_v,domain_end_v,CImGui.ImGuiCond_Once)
        if (ImPlot.BeginPlot("f:R^2->R", "u", "v"))
            ImPlot.PushColormap(ImPlot.ImPlotColormap_Spectral)
            ImPlot.PlotHeatmap("f(u,v)", zs, FUNC_HEATMAP_RESOLUTION, FUNC_HEATMAP_RESOLUTION;
                label_fmt="", bounds_min=ImPlotPoint(domain_start_u,domain_start_v), bounds_max=ImPlotPoint(domain_end_u,domain_end_v))
            ImPlot.EndPlot()
        end
    end

    return (func,nothing,EDIT_NODE_NONE)
end

function CreateFunction(callback::Function,inputs::Vector{Tuple{Float64,Float64}},parents::Vector{NodeHandle}=NodeHandle[];
    output_count::Union{Integer,Nothing}=nothing)

    if (output_count === nothing)
        default_values = [(a + b) / 2.0 for (a,b) in inputs]
        default_result = callback(default_values...)
        output_count = length(default_result)
    end

    func = Func(callback,inputs,output_count,parents)

    return add_node!(func)
end





export CreateFunction#, Curve
