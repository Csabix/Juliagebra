
# ? ---------------------------------
# ! SourceValueHolderPlan{T}
# ? ---------------------------------

mutable struct SourceValueHolderPlan{T} <: SourceValueHolderPlanDNA{T}
    _plan::ValueHolderPlan{T}
    _value::T

    function SourceValueHolderPlan{T}(value::T) where T
        plan = ValueHolderPlan{T}(DEFAULT_CALLBACK,Vector{PlanDNA}())
        new{T}(plan,value)
    end
end

function _SourceValueHolderPlan_(self::SourceValueHolderPlanDNA{T})::SourceValueHolderPlan{T} where T
    error("Missing func!")
end
# ? This class is usable as-is.
function _SourceValueHolderPlan_(self::SourceValueHolderPlan{T})::SourceValueHolderPlan{T} where T
    return self
end

function _ValueHolderPlan_(self::SourceValueHolderPlanDNA{T})::ValueHolderPlan{T} where T
    return _SourceValueHolderPlan_(self)._plan
end

# ? ---------------------------------
# ! SourceValueHolderDependent{T}
# ? ---------------------------------

mutable struct SourceValueHolderDependent{T} <: SourceValueHolderDNA{T}
    _dependent::ValueHolderDependent{T}
    _value::T

    function SourceValueHolderDependent{T}(plan::SourceValueHolderPlanDNA{T}) where T
        dependent = ValueHolderDependent{T}(plan)
        value = _SourceValueHolderPlan_(plan)._value
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
onNodeEval(self::SourceValueHolderDNA) = error("Impossible!")
evalCallbackDpReturn(self::SourceValueHolderDNA, ::Any) = error("Impossible")

function Plan2Dependent(plan::SourceValueHolderPlan{T})::SourceValueHolderDependent{T} where T
    return SourceValueHolderDependent{T}(plan)
end

# ? ---------------------------------
# ! SourceValueHolder(T)
# ? ---------------------------------

function _SourceValueHolder(;
        _app::AppDNA = implicitApp,
        _value::T
    ) where T

    plan = SourceValueHolderPlan{T}(_value)
    submit!(_app,plan)
    return plan
end

function SourceValueHolder(value::T)::SourceValueHolderPlan{T} where T
    return _SourceValueHolder(_value = value)
end

ValueHolder(value) = SourceValueHolder(value)

export SourceValueHolder