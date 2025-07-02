# ? ---------------------------------
# ! PlanDNA
# ? ---------------------------------

mutable struct Plan

    _algebra::Union{Nothing,AlgebraDNA}
    _graphParents::Vector{PlanDNA}
    _callback::Function

    function Plan(graphParents::Vector{T},callback::Function) where T<:PlanDNA
        new(nothing,graphParents,callback)
    end
end

_Plan_(self::PlanDNA)::Plan = error("Missing func!")
_Plan_(self::RenderedPlanDNA)::Plan = error("Missing func!")


