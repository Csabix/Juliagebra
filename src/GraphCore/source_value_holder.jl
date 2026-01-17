
# ? ---------------------------------
# ! SourceValueHolderPlan{T}
# ? ---------------------------------

mutable struct SourceValueHolderPlan{T} <: ValueHolderPlanDNA{T}
    _plan::ValueHolderPlan{T}
    _value::T

    function SourceValueHolderPlan{T}(value::T) where T
        plan = ValueHolderPlan{T}(DEFAULT_CALLBACK,Vector{PlanDNA}())
        new{T}(plan,value)
    end
end

function _ValueHolderPlan_(self::SourceValueHolderPlan{T})::ValueHolderPlan{T} where T
    return self._plan
end

# ? ---------------------------------
# ! SourceValueHolderDependent{T}
# ? ---------------------------------

mutable struct SourceValueHolderDependent{T} <: ValueHolderDNA{T}
    _dependent::ValueHolder{T}
    _value::T

    function SourceValueHolderDependent{T}(plan::SourceValueHolderPlan{T}) where T
        dependent = ValueHolder{T}(plan)
        value = plan._value
        new(dependent,value)
    end
end

function _ValueHolder_(self::SourceValueHolderDependent{T})::ValueHolder{T} where T
    return self._dependent
end

getField(self::SourceValueHolderDependent) = return self._value

onNodeEval(self::SourceValueHolderDependent) = error("Impossible!")
function evalCallbackDpEntry(self::SourceValueHolderDependent{T})::T where T
    return self._value
end

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

export SourceValueHolder