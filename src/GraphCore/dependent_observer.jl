# ? ---------------------------------
# ! DependentObserver
# ? ---------------------------------

@kwdef mutable struct Observer{T<:ObservedDNA}
    _observedItems::Vector{T} = Vector{T}()
    _hasInstance::Bool = false
end

_Observer_(self::ObserverDNA)::Observer = error("Missing func!")

Base.getindex(self::ObserverDNA,index) = return _Observer_(self)._observedItems[index]
Base.length(self::ObserverDNA) = return length(_Observer_(self)._observedItems)
getObservedItems(self::ObserverDNA) = return _Observer_(self)._observedItems
_setHasInstance!(self::ObserverDNA) = _Observer_(self)._hasInstance = true
hasInstance(self::ObserverDNA)::Bool = return _Observer_(self)._hasInstance

function add!!(collector::ObserverDNA,collected::ObservedDNA)
    observer = _Observer_(collector)
    observed = _Observed_(collected)

    push!(observer._observedItems,collected)
    
    observed._observer = collector
    observed._observerID = length(observer._observedItems)

    push!(getSchedule(collected)._set,collector)
end

postGraphEval(self::ObserverDNA) = syncAll!(self)

added!(itemCollector::ObserverDNA{T},item::T) where T = error("Missing \"added!\" func for types of (\"$(typeof(itemCollector))\",\"$(typeof(item))\")!")
sync!(itemCollector::ObserverDNA{T},item::T) where T = error("Missing \"sync!\" func for types of (\"$(typeof(itemCollector))\",\"$(typeof(item))\")!")
syncAll!(self::ObserverDNA) = error("Missing \"syncAll!\" func for types of \"$(typeof(self))\"!")