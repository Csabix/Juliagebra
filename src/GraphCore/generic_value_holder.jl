
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
build!(GenericValueHolderDependent{T}(callback, dependents))

# YELLOW Thread
ValueHolder(callback::Function,T::Type,dependents::Vector{<:DependentDNA}) = GenericValueHolder(callback,T,dependents)

export GenericValueHolder