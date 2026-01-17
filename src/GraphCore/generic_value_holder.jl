# ? ---------------------------------
# ! GenericValueHolder{T}
# ? ---------------------------------

mutable struct GenericValueHolder{T} <: ValueHolderPlanDNA{T}
    _plan::ValueHolderPlan{T}

    function GenericValueHolder(;
        _call::Function = DEFAULT_CALLBACK,
        _deps::DependentsT = Vector{PlanDNA}(),
        _T::Type)

        plan = ValueHolderPlan{_T}(_call,_deps)
        new{_T}(plan)
    end
end

function _ValueHolderPlan_(self::GenericValueHolder{T})::ValueHolderPlan{T} where T
    return self._plan
end

function _GenericValueHolder(;
        _app::AppDNA = implicitApp,
        _call::Function = DEFAULT_CALLBACK,
        _deps::DependentsT = Vector{PlanDNA}(),
        _T::Type)

        plan = GenericValueHolder(_call = _call, _deps = _deps, _T = _T)
        submit!(_app,plan)
        return plan
end

"""
Acts as external constructor.

Use only if submission to App is needed!
"""
GenericValueHolder{T}(callback::Function,dependents::DependentsT) where T =
_GenericValueHolder(_call = callback, _deps = dependents, _T = T)

export GenericValueHolder

# ? ---------------------------------
# ! GenericValueHolderDependent{T}
# ? ---------------------------------

mutable struct GenericValueHolderDependent{T} <: ValueHolderDNA{T}
    _dependent::ValueHolder{T}
    _value::Union{T,Nothing}

    function GenericValueHolderDependent{T}(plan::GenericValueHolder{T}) where T
        dependent = ValueHolder{T}(plan)

        genericDependent = new(dependent,nothing)
        onNodeEval(genericDependent)
        return genericDependent
    end
end

function _ValueHolder_(self::GenericValueHolderDependent{T})::ValueHolder{T} where T
    return self._dependent
end

getField(self::GenericValueHolderDependent) = return self._value

onNodeEval(self::GenericValueHolderDependent) = evalCallbackDp(self)
function evalCallbackDpEntry(self::GenericValueHolderDependent{T})::T where T
    return self._value
end

evalCallbackDpReturn(self::GenericValueHolderDependent{T}, value::T) where T = self._value = value
evalCallbackDpReturn(self::GenericValueHolderDependent{T}, value::Nothing) where T = (value isa T) ? (self._value = value) : error("Returned $(value) doesn't conform to $(T)!")

function Plan2Dependent(plan::GenericValueHolder{T})::GenericValueHolderDependent{T} where T
    return GenericValueHolderDependent{T}(plan)
end