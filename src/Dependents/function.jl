
struct Func
    callback::Function
    function Func(callback)
        new(callback)
    end
end

convert_callback_entry(func::Func)::Function = func.callback
convert_callback_result(func::Func, ::Any) = func

function CreateFunction(callback::Function,parents::Union{Vector{NodeHandle},Nothing}=nothing)
    return add_node!(Func(callback))
end

export CreateFunction
