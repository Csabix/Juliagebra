# ? ---------------------------------
# ! RenderedDependentDNA
# ? ---------------------------------

mutable struct RenderedDependent <: SubjectDNA
    _subject::Subject

    function RenderedDependent(callback::Function,dependents::Vector{<:DependentDNA})
        subject = Subject(callback,dependents)
        return new(subject)
    end
end

_RenderedDependent_(self::RenderedDependentDNA)::RenderedDependent = error("Missing \"_RenderedDependent_\" func for instance of RenderedDependentDNA")
_Subject_(self::RenderedDependentDNA)::Subject = _RenderedDependent_(self)._subject
