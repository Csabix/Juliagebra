
# ? ---------------------------------
# ! ValueHolderDependent{T}
# ? ---------------------------------

mutable struct ValueHolderDependent{T} <: DependentDNA
    _dependent::Dependent

    # YELLOW Thread
    function ValueHolderDependent{T}(callback::Function, dependents::Vector{<:DependentDNA}) where T
        dependent = Dependent(callback,dependents)
        new(dependent)
    end
end

function _ValueHolderDependent_(self::ValueHolderDNA{T})::ValueHolderDependent{T} where T
    error("Missing func!")
end
_Dependent_(self::ValueHolderDNA)::Dependent = _ValueHolderDependent_(self)._dependent


function getField(self::ValueHolderDNA{T})::T where T
    error("Missing func!")
end

function evalCallbackDpEntry(self::ValueHolderDNA{T})::T where T
    return getField(self)
end

export ValueHolder