
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

edit_node_overload(func::Func)::Bool = true
function edit_node(func::Func,::Any,::Dict{DataType,Renderer},::NodeHandle)::Tuple{Any,Any,Int}

    if (func.input_count == 1 && func.output_count > 0)

        domain_start = func.domain[1][1]
        domain_end = func.domain[1][2]
        xs = collect(range(domain_start,domain_end,1000))
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
    elseif (func.input_count == 2 && func.output_count == 1) # TODO: 1..3

        domain_start_u = func.domain[1][1]
        domain_end_u = func.domain[1][2]
        domain_start_v = func.domain[2][1]
        domain_end_v = func.domain[2][2]
        xs = collect(range(domain_start_u,domain_end_u,10))
        ys = collect(range(domain_start_v,domain_end_v,10))
        zs = [@invokelatest func.callback(u,v) for u in xs, v in ys]

        ImPlot.SetNextAxesLimits(domain_start_u,domain_end_u,domain_start_v,domain_end_v,CImGui.ImGuiCond_Once)
        if (ImPlot.BeginPlot("Image", "u", "v"))
            ImPlot.PushColormap(ImPlot.ImPlotColormap_Spectral)
            ImPlot.PlotHeatmap("f(u,v)", zs, 10, 10)
            ImPlot.EndPlot()
        end
    end

    return (func,nothing,EDIT_NODE_NONE)
end

# inputs: 2×d -> d amount of intervals
# eg. [p1,p2,p3] × [0.0; 1.0]   = [(p1, 0.0),(p1, 1.0),(p2, 0.0),(p2, 1.0),(p3, 0.0),(p3, 1.0)]       if step is 1.0
#       -> [(0,0,0),(1,1,1),(0,0,0),(2,2,2),(0,0,0),(3,3,3)]
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

export CreateFunction
