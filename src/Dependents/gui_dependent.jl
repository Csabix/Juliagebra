
# ? ---------------------------------
# ! GuiDependentDNA
# ? ---------------------------------

mutable struct GuiDependent <: ObservedDNA
    _observed::Observed

    function GuiDependent(callback::Function, dependents::Vector{<:DependentDNA})
        return new(Observed(callback,dependents))
    end
end

_GuiDependent_(self::GuiDependentDNA)::GuiDependent = error("Missing func!")
_Observed_(self::GuiDependentDNA)::Observed = _GuiDependent_(self)._observed
