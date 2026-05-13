# ? ---------------------------------
# ! DependentObserver
# ? ---------------------------------

@kwdef mutable struct Observer{T<:SubjectDNA}
    _subjectItems::Vector{T} = Vector{T}()
    _hasInstance::Bool = false
end

_Observer_(self::ObserverDNA)::Observer = error("Missing func!")

Base.getindex(self::ObserverDNA,index) = return _Observer_(self)._subjectItems[index]
Base.length(self::ObserverDNA) = return length(_Observer_(self)._subjectItems)
getSubjectItems(self::ObserverDNA) = return _Observer_(self)._subjectItems
_setHasInstance!(self::ObserverDNA) = _Observer_(self)._hasInstance = true
hasInstance(self::ObserverDNA)::Bool = return _Observer_(self)._hasInstance

function add!!(collector::ObserverDNA,collected::SubjectDNA)
    observer = _Observer_(collector)
    subject = _Subject_(collected)

    push!(observer._subjectItems,collected)

    subject._observer = collector
    subject._observerID = length(observer._subjectItems)

    #push!(getSchedule(collected)._set,collector)
end

added!(itemCollector::ObserverDNA{T},item::T) where T = error("Missing \"added!\" func for types of (\"$(typeof(itemCollector))\",\"$(typeof(item))\")!")
sync!(itemCollector::ObserverDNA{T},item::T) where T = error("Missing \"sync!\" func for types of (\"$(typeof(itemCollector))\",\"$(typeof(item))\")!")