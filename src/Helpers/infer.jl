
function _CheckAndGetSingletonType(Ts::Vector,::Type{V})::Type{<:V} where {V}
    if (length(Ts) == 0)
        error("No types could be infered!")
    end

    if (length(Ts) != 1)
        error("Multiple types were infered [$(Ts)]!")
    end

    T::Type = Ts[1]

    if (!(T <: V))
        error("$(T) isn't the child of $(V)")
    end

    return T
end

function InferSingletonDefinitionFor(instance::U,func::Function,::Type{V})::Type{<:V} where {U,V}
    Ts = Base.return_types(func,Tuple{typeof(instance)})
    return _CheckAndGetSingletonType(Ts,V)
end

function InferSingletonDefinitionFor(::Type{U},func::Function,::Type{V})::Type{<:V} where {U,V}
    Ts = Base.return_types(func,Tuple{U})
    return _CheckAndGetSingletonType(Ts,V)
end

function InferSingletonDefinitionFor(::Type{U},func::Base.Callable,::Type{V})::Type{<:V} where {U,V}
    Ts = Base.return_types(func,Tuple{U})
    return _CheckAndGetSingletonType(Ts,V)
end

function InferSingletonDefinitionFor(types::Type{U},func::Function,::Type{V})::Type{<:V} where {U <: Tuple,V}
    Ts = Base.return_types(func,types)
    return _CheckAndGetSingletonType(Ts,V)
end