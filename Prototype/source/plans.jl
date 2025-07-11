# ? ---------------------------------
# ! PlanDNA
# ? ---------------------------------

mutable struct Plan

    _algebra::Union{Nothing,AlgebraDNA}
    _graphParents::Vector{PlanDNA}
    _callback::Function

    function Plan(callback::Function,graphParents::Vector{T},) where T<:PlanDNA
        new(nothing,graphParents,callback)
    end
end

_Plan_(self::PlanDNA)::Plan = error("Missing func!")

# ? ---------------------------------
# ! RenderedPlanDNA
# ? ---------------------------------

mutable struct RenderedPlan <: PlanDNA
    _renderer::Union{Nothing,RendererDNA}
    _plan::Plan
    
    function RenderedPlan(callback::Function, graphParents::Vector{T},) where T<:PlanDNA
        plan = Plan(callback,graphParents)
        new(nothing,plan)
    end
end

_Plan_(self::RenderedPlanDNA) = return _RenderedPlan_(self)._plan
_RenderedPlan_(self::RenderedPlanDNA)::RenderedPlan = error("Missing func!")
