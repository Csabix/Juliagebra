
# ? ---------------------------------
# ! GuiDependentDNA
# ? ---------------------------------

mutable struct GuiDependent <: ObservedDNA
    _observed::Observed
    _label::String

    function GuiDependent(callback::Function, dependents::Vector{<:DependentDNA},label::String)
        return new(Observed(callback,dependents),label)
    end
end

_GuiDependent_(self::GuiDependentDNA)::GuiDependent = error("Missing func!")
_Observed_(self::GuiDependentDNA)::Observed = _GuiDependent_(self)._observed
getLabel(self::GuiDependentDNA)::String = _GuiDependent_(self)._label