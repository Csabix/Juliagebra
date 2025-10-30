# ? ---------------------------------
# ! PlanDNA
# ? ---------------------------------

mutable struct Plan

    _dependent::Union{Nothing,DependentDNA}
    _graphParents::Vector{PlanDNA}
    _callback::Function

    function Plan(callback::Function,graphParents::Vector{T}) where T<:PlanDNA
        new(nothing,graphParents,callback)
    end
end

_Plan_(self::PlanDNA)::Plan = error("Missing func!")

# ? ---------------------------------
# ! ObservedlanDNA
# ? ---------------------------------

mutable struct ObservedPlan <: PlanDNA
    
    _plan::Plan

    function ObservedPlan(callback::Function,graphParents::Vector{T}) where T<:PlanDNA
        plan = Plan(callback,graphParents)
        new(plan)
    end
end

_ObservedPlan_(self::ObservedPlanDNA)::ObservedPlan = error("Missing func!")
_Plan_(self::ObservedPlanDNA)::Plan = return _ObservedPlan_(self)._plan