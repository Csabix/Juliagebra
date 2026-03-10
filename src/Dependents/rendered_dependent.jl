# ? ---------------------------------
# ! RenderedDependentDNA
# ? ---------------------------------

mutable struct RenderedDependent <: ObservedDNA
    _observed::Observed
    
    function RenderedDependent(callback::Function,dependents::Vector{<:DependentDNA})
        observed = Observed(callback,dependents)
        return new(observed)
    end
end

_RenderedDependent_(self::RenderedDependentDNA)::RenderedDependent = error("Missing \"_RenderedDependent_\" func for instance of RenderedDependentDNA")
_Observed_(self::RenderedDependentDNA)::Observed = _RenderedDependent_(self)._observed
