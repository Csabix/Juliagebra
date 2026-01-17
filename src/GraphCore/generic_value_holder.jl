# ? ---------------------------------
# ! GenericValueHolderPlan{T}
# ? ---------------------------------

mutable struct GenericValueHolderPlan{T} <: PlanDNA
    _plan::Plan
    _startT::Union{T,Nothing}

    function GenericValueHolderPlan{T}(callback::Function,plans::Vector{<:PlanDNA},startT::Union{T,Nothing}) where T
        plan = Plan(callback,plans)
        new{T}(plan,startT)
    end
end

_Plan_(self::GenericValueHolderPlan)::Plan = return self._plan

# ? ---------------------------------
# ! GenericValueHolder{T}
# ? ---------------------------------

mutable struct GenericValueHolder{T} <: DependentDNA
    _dependent::Dependent
    _currT::Union{T,Nothing}

    function GenericValueHolder{T}(plan::GenericValueHolderPlan{T}) where T
        dependent = Dependent(plan)
        currT = plan._startT

        genericDependent = new(dependent,currT)
        onNodeEval(genericDependent)
        return genericDependent
    end
end

_Dependent_(self::GenericValueHolder)::Dependent = return self._dependent

getField(self::GenericValueHolder) = return self._currT

onNodeEval(self::GenericValueHolder) = evalCallbackDp(self)
function evalCallbackDpEntry(self::GenericValueHolder{T})::T where {T}
    return self._currT
end

evalCallbackDpReturn(self::GenericValueHolder{T}, currT::T) where T = self._currT = currT
evalCallbackDpReturn(self::GenericValueHolder, ::Nothing) = nothing

function Plan2Dependent(plan::GenericValueHolderPlan{T}) where T
    return GenericValueHolder{T}(plan)
end

# ? ---------------------------------
# ! GenericValueHolder
# ? ---------------------------------

function _GenericValueHolder(;
                _app::AppDNA = implicitApp,
                _call::Function = () -> (return nothing),
                _deps::DependentsT = Vector{PlanDNA}(),
                _startT::Union{T,Nothing} = nothing,
                _T::Type{T}
)::GenericValueHolderPlan{T} where {T}
    plan = GenericValueHolderPlan{T}(_call,_deps,_startT)
    submit!(_app,plan)
    return plan
end

GenericValueHolder(startT::T) where {T} = 
_GenericValueHolder(_startT = startT, _T = T)

# ? Works, because Julia can figure out I'm just changing the syntax
# ? and T can be inferred in _GenericValueHolder
GenericValueHolder{T}(startT) where {T} = 
_GenericValueHolder(_startT = T(startT), _T = T)

GenericValueHolder{T}(callback::Function,dependents::DependentsT) where {T} = 
_GenericValueHolder(_call = callback, _deps = dependents, _T = T)

export GenericValueHolder