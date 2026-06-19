
# ? ---------------------------------
# ! GenericValueHolderDependent{T}
# ? ---------------------------------

mutable struct GenericValueHolderDependent{T} <: ValueHolderDNA{T}
    _dependent::ValueHolderDependent{T}
    _value::Union{T,Nothing}

    # YELLOW Thread
    function GenericValueHolderDependent{T}(callback::Function, dependents::Vector{<:DependentDNA}) where T
        dependent = ValueHolderDependent{T}(callback,dependents)
        new(dependent,nothing)
    end
end

function Base.eltype(dependent::GenericValueHolderDependent{T})::DataType where T
    return T
end

function _ValueHolderDependent_(self::GenericValueHolderDependent{T})::ValueHolderDependent{T} where T
    return self._dependent
end

function getField(self::GenericValueHolderDependent{T})::T where T 
    return self._value
end

# YELLOW Thread
# RED Thread
onNodeEval(self::GenericValueHolderDependent) = evalCallbackDp(self)
evalCallbackDpReturn(self::GenericValueHolderDependent{T}, value::T) where T = self._value = value
evalCallbackDpReturn(self::GenericValueHolderDependent{T}, value::Nothing) where T = (value isa T) ? (self._value = value) : error("Returned $(value) doesn't conform to $(T)!")

# ? ---------------------------------
# ! GenericValueHolder(T)
# ? ---------------------------------

# YELLOW Thread
GenericValueHolder(callback::Function,T::Type,dependents::Vector{<:DependentDNA}) =
Build!(GenericValueHolderDependent{T}(callback, dependents))

# YELLOW Thread
ValueHolder(callback::Function,T::Type,dependents::Vector{<:DependentDNA}) = GenericValueHolder(callback,T,dependents)

macro ValueHolder(callback::Expr, T)
    _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.ValueHolder, Vector{Any}(), Dict{Symbol,Any}(), (cb, deps) -> (cb,T,deps))
end

export GenericValueHolder
export @ValueHolder
