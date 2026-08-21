
struct Func
    callback::Function
    input_count::Integer
    output_count::Integer
    parents::Vector{NodeHandle}
    function Func(callback::Function,input_count::Integer,output_count::Integer,parents::Vector{NodeHandle})
        new(callback,input_count,output_count,parents)
    end
end

convert_callback_entry(func::Func)::Function = func.callback
convert_callback_result(func::Func, ::Any) = func

# inputs: 2×d -> d amount of intervals
# eg. [p1,p2,p3] × [0.0; 1.0]   = [(p1, 0.0),(p1, 1.0),(p2, 0.0),(p2, 1.0),(p3, 0.0),(p3, 1.0)]       if step is 1.0
#       -> [(0,0,0),(1,1,1),(0,0,0),(2,2,2),(0,0,0),(3,3,3)]
function CreateFunction(callback::Function,inputs::Vector{Tuple{Float64,Float64}},parents::Vector{NodeHandle}=NodeHandle[];
    output_count::Union{Integer,Nothing}=nothing)

    if (output_count === nothing)
        default_values = [(a + b) / 2.0 for (a,b) in inputs]
        println(default_values)
        default_result = callback(default_values...)
        println(length(default_result))
    end

    func = Func(callback,length(inputs),0,parents)

    return add_node!(func)
end

export CreateFunction
