# ? ---------------------------------
# ! SubjectDNA
# ? ---------------------------------

mutable struct Subject <: DependentDNA
    _dependent::Dependent
    _observer::Union{ObserverDNA,Nothing}
    _observerID::Int
end

_Dependent_(self::SubjectDNA)::Dependent = return _Subject_(self)._dependent
_Subject_(self::SubjectDNA)::Subject = error("Missing func!")

getObserverID(self::SubjectDNA)::Int = return _Subject_(self)._observerID
getObserver(self::SubjectDNA)::Union{ObserverDNA,Nothing} = return _Subject_(self)._observer

function Subject(callback::Function,graphParents::Vector{<:DependentDNA})::Subject
    dependent = Dependent(callback,graphParents)
    observer = nothing
    observerID = 0
    return Subject(dependent,observer,observerID)
end

function isUnbuilt(self::SubjectDNA)::Bool
    return _isUnbuilt(_Dependent_(self)) && isnothing(getObserver(self)) && (getObserverID(self) == 0)
end

function hasObserver(self::SubjectDNA)
    subject = _Subject_(self)
    id = subject._observerID
    return id != 0 &&
           _Observer_(subject._observer)._subjectItems[id] === self
end

