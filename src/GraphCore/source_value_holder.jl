
# ? ---------------------------------
# ! SourceValueHolderDependent{T}
# ? ---------------------------------

mutable struct SourceValueHolderDependent{T} <: SourceValueHolderDNA{T}
    _dependent::ValueHolderDependent{T}
    _value::T

    # YELLOW Thread
    function SourceValueHolderDependent{T}(value::T) where T
        dependent = ValueHolderDependent{T}(() -> (return nothing), Vector{DependentDNA}())
        new(dependent,value)
    end
end

function _SourceValueHolder_(self::SourceValueHolderDNA{T})::SourceValueHolderDependent{T} where T
    error("Missing func!")
end
# ? This class is usable as-is.
function _SourceValueHolder_(self::SourceValueHolderDependent{T})::SourceValueHolderDependent{T} where T
    return self
end

function _ValueHolderDependent_(self::SourceValueHolderDNA{T})::ValueHolderDependent{T} where T
    return _SourceValueHolder_(self)._dependent
end

function getField(self::SourceValueHolderDNA{T})::T where T 
    return _SourceValueHolder_(self)._value
end

# YELLOW Thread
# RED Thread
onNodeEval(self::SourceValueHolderDNA) = return nothing
evalCallbackDpReturn(self::SourceValueHolderDNA, ::Any) = return nothing

# ? ---------------------------------
# ! SourceValueHolder(T)
# ? ---------------------------------

# YELLOW Thread
function SourceValueHolder(value::T)::SourceValueHolderDependent{T} where T
    return Build!(SourceValueHolderDependent{T}(value))
end

# YELLOW Thread
ValueHolder(value) = SourceValueHolder(value)

export SourceValueHolder