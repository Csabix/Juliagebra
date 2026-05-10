
# ? ---------------------------------
# ! GuiDependentDNA
# ? ---------------------------------

mutable struct GuiDependent <: SubjectDNA
    _subject::Subject
    _label::String

    function GuiDependent(callback::Function, dependents::Vector{<:DependentDNA},label::String)
        return new(Subject(callback,dependents),label)
    end
end

_GuiDependent_(self::GuiDependentDNA)::GuiDependent = error("Missing func!")
_Subject_(self::GuiDependentDNA)::Subject = _GuiDependent_(self)._subject
getLabel(self::GuiDependentDNA)::String = _GuiDependent_(self)._label