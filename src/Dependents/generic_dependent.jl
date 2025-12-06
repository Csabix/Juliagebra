# ? ---------------------------------
# ! GenericDependentPlan{T}
# ? ---------------------------------

mutable struct GenericDependentPlan{T} <: PlanDNA
    _plan::Plan
    _startT::T

    function GenericDependentPlan{T}(callback::Function,plans::Vector{<:PlanDNA},startT::T) where T
        plan = Plan(callback,plans)
        new{T}(plan,startT)
    end
end

_Plan_(self::GenericDependentPlan)::Plan = return self._plan

# ? ---------------------------------
# ! GenericDependent{T}
# ? ---------------------------------

mutable struct GenericDependent{T} <: DependentDNA
    _dependent::Dependent
    _currT::T

    function GenericDependent{T}(plan::GenericDependentPlan{T}) where T
        dependent = Dependent(plan)
        currT = plan._startT

        genericDependent = new(dependent,currT)
        onNodeEval(genericDependent)
        return genericDependent
    end
end

_Dependent_(self::GenericDependent)::Dependent = return self._dependent

getGenericDependentField(self::GenericDependent,fieldVal::Val{:val}) = return self._currT
getGenericDependentField(self::GenericDependent{T},fieldVal::Val{:T}) where T = return T
Base.getindex(self::GenericDependent,fieldSymbol::Symbol) = return getGenericDependentField(self,Val(fieldSymbol))

onNodeEval(self::GenericDependent) = evalNodeDp(self)
evalNode(self::GenericDependent) = getCallback(self)(getGraphParents(self)...)
evalNodeDpReturn(self::GenericDependent{T}, currT::T) where T = self._currT = currT
evalNodeDpReturn(self::GenericDependent, ::Nothing) = nothing

function Plan2Dependent(plan::GenericDependentPlan{T}) where T
    return GenericDependent{T}(plan)
end