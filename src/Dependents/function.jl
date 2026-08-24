
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

    # println("called: $(func.input_count), $(func.output_count)")

    if (func.input_count == 1 && func.output_count == 1)

        # println(methods(func.callback))
        domain_start = func.domain[1][1]
        domain_end = func.domain[1][2]
        xs = collect(range(domain_start,domain_end,1000))
        ys = [@invokelatest func.callback(t) for t in xs]
        # data = [func.callback(i / 1000 * (domain_end - domain_start)) for t in 1:1000]

        ImPlot.SetNextAxesLimits(func.domain[1][1],func.domain[1][2],-1.0,1.0,CImGui.ImGuiCond_Once)
        if (ImPlot.BeginPlot("f:R->R", "x", "y"))
            ImPlot.PlotLine("f(x)", xs, ys)
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
