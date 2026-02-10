# ? ---------------------------------
# ! GenericValueHolderPlan{T}
# ? ---------------------------------

mutable struct GenericValueHolderPlan{T} <: ValueHolderPlanDNA{T}
    _plan::ValueHolderPlan{T}

    function GenericValueHolderPlan{T}(callback::Function,dependents::DependentsT) where T
        plan = ValueHolderPlan{T}(callback,dependents)
        new{T}(plan)
    end
end

function _ValueHolderPlan_(self::GenericValueHolderPlan{T})::ValueHolderPlan{T} where T
    return self._plan
end

# ? ---------------------------------
# ! GenericValueHolderDependent{T}
# ? ---------------------------------

mutable struct GenericValueHolderDependent{T} <: ValueHolderDNA{T}
    _dependent::ValueHolderDependent{T}
    _value::Union{T,Nothing}

    function GenericValueHolderDependent{T}(plan::GenericValueHolderPlan{T}) where T
        dependent = ValueHolderDependent{T}(plan)

        self = new(dependent,nothing)
        onNodeEval(self)
        return self
    end
end

function _ValueHolderDependent_(self::GenericValueHolderDependent{T})::ValueHolderDependent{T} where T
    return self._dependent
end

function getField(self::GenericValueHolderDependent{T})::T where T 
    return self._value
end
onNodeEval(self::GenericValueHolderDependent) = evalCallbackDp(self)
evalCallbackDpReturn(self::GenericValueHolderDependent{T}, value::T) where T = self._value = value
evalCallbackDpReturn(self::GenericValueHolderDependent{T}, value::Nothing) where T = (value isa T) ? (self._value = value) : error("Returned $(value) doesn't conform to $(T)!")

function Plan2Dependent(plan::GenericValueHolderPlan{T})::GenericValueHolderDependent{T} where T
    return GenericValueHolderDependent{T}(plan)
end

# ? ---------------------------------
# ! GenericValueHolder(T)
# ? ---------------------------------

function _GenericValueHolder(;
        _app::AppDNA = implicitApp,
        _call::Function = DEFAULT_CALLBACK,
        _deps::DependentsT = Vector{PlanDNA}(),
        _T::Type)

        plan = GenericValueHolderPlan{_T}(_call, _deps)
        submit!(_app,plan)
        return plan
end

GenericValueHolder(callback::Function,T::Type,dependents::DependentsT) =
_GenericValueHolder(_call = callback, _deps = dependents, _T = T)

ValueHolder(callback::Function,T::Type,dependents::DependentsT) = GenericValueHolder(callback,T,dependents)

export GenericValueHolder