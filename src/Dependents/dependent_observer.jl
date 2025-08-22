@kwdef mutable struct Observer{T<:ObservedDNA}
    _observedItems::Vector{T} = Vector{T}()
end

_Observer_(self::ObserverDNA)::Observer = error("Missing func!")

added!(itemCollector::ObserverDNA{T},item::T) where T = error("Missing \"added!\" func for types of (\"$(typeof(itemCollector))\",\"$(typeof(item))\")!")
sync!(itemCollector::ObserverDNA{T},item::T) where T = error("Missing \"sync!\" func for types of (\"$(typeof(itemCollector))\",\"$(typeof(item))\")!")
addedAll!(self::ObserverDNA) = error("Missing \"addedAll!\" func for type of \"$(typeof(self))\"!")
syncAll!(self::ObserverDNA) = error("Missing \"syncAll!\" func for types of \"$(typeof(self))\"!")