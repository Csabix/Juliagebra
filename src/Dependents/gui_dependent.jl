
# ? ---------------------------------
# ! GuiDependentDNA
# ? ---------------------------------

mutable struct GuiDependent <: ObservedDNA
    _observed::Observed

    function GuiDependent(plan::GuiPlanDNA)
        observed = Observed(plan)
        return GuiDependent(observed)
    end
end

_GuiDependent_(self::GuiDependentDNA)::GuiDependent = error("Missing func!")
_Observed_(self::GuiDependentDNA)::Observed = _GuiDependent_(self)._observed
