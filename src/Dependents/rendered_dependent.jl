# ? ---------------------------------
# ! RenderedDependentDNA
# ? ---------------------------------

mutable struct RenderedDependent <: ObservedDNA
    _observed::Observed
end

function RenderedDependent(plan::RenderedPlanDNA)
    observed = Observed(plan)
    return RenderedDependent(observed)
end

_RenderedDependent_(self::RenderedDependentDNA)::RenderedDependent = error("Missing \"_RenderedDependent_\" func for instance of RenderedDependentDNA")
_Observed_(self::RenderedDependentDNA)::Observed = _RenderedDependent_(self)._observed
