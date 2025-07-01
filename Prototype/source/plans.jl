# ? ---------------------------------
# ! PlanDNA
# ? ---------------------------------

mutable struct Plan

    _algebra::Union{Nothing,AlgebraDNA}
    
    function Plan()
        new(nothing)
    end
end

_Plan_(self::PlanDNA)::Plan = error("Missing func!")   

