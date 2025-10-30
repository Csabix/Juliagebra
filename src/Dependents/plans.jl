# ? ---------------------------------
# ! RenderedPlanDNA
# ? ---------------------------------

mutable struct RenderedPlan <: ObservedPlanDNA
    _plan::ObservedPlan
    
    function RenderedPlan(callback::Function, graphParents::Vector{T},) where T<:PlanDNA
        plan = ObservedPlan(callback,graphParents)
        new(plan)
    end
end

_ObservedPlan_(self::RenderedPlanDNA) = return _RenderedPlan_(self)._plan
_RenderedPlan_(self::RenderedPlanDNA)::RenderedPlan = error("Missing func!")

# ? ---------------------------------
# ! GuiPlanDNA
# ? ---------------------------------

mutable struct GuiPlan <: ObservedPlanDNA
    _plan::ObservedPlan

    function GuiPlan(callback::Function,graphParents::Vector{T}) where T<:PlanDNA
        plan = ObservedPlan(callback,graphParents)
        new(plan)
    end
end

_ObservedPlan_(self::GuiPlanDNA) = return _GuiPlan_(self)._plan
_GuiPlan_(self::GuiPlanDNA)::GuiPlan = error("Missing func!")