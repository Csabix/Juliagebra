
# ? ---------------------------------
# ! Synchronizer
# ? ---------------------------------

"""
Calls sync!() and syncAll!() on arrived Dependents.
"""
@kwdef mutable struct Synchronizer
    _in::Queue{ObservedDNA} = Queue{ObservedDNA}()
    _taken::Int = 0
end

Base.put!(self::Synchronizer, osberved::ObservedDNA) = push!(self._in,osberved)
Base.take!(self::Synchronizer)::ObservedDNA = return popfirst!(self._in)
Base.length(self::Synchronizer) = return length(self._in)

function processBatch!(self::Synchronizer)
    self._taken = length(self)
    observers = Set{ObserverDNA}()
    
    for _ in 1:self._taken
        d::DependentDNA = take!(self)
        o::ObserverDNA = _handleSyncCall(d)
        push!(observers,o)
    end

    for o in observers in 
        syncAll!(o)
    end
end

function _handleSyncCall(self::ObservedDNA)
    o::ObserverDNA = getObserver(self)
    sync!(o,self)
    return o
end