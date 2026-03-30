
# ? ---------------------------------
# ! Synchronizer
# ? ---------------------------------

"""
Calls sync!() and syncAll!() on arrived Dependents.
"""
@kwdef mutable struct Synchronizer
    _in::Queue{DependentDNA} = Queue{DependentDNA}()
    _taken::Int = 0
end

Base.put!(self::Synchronizer, d::DependentDNA) = push!(self._in,d)
Base.take!(self::Synchronizer)::DependentDNA = return popfirst!(self._in)
Base.length(self::Synchronizer) = return length(self._in)

function processBatch!(self::Synchronizer, ::AppDNA)
    self._taken = length(self)
    observers = Set{ObserverDNA}()
    
    for _ in 1:self._taken
        d::DependentDNA = take!(self)
        o::Union{ObserverDNA,Nothing} = _handleSyncCall(d)
        
        if !isnothing(o)
            push!(observers,o)
        end
    end

    for o in observers in 
        syncAll!(o)
    end
end

function _handleSyncCall(::DependentDNA)
    return nothing
end

function _handleSyncCall(self::ObservedDNA)
    o::ObserverDNA = getObserver(self)
    sync!(o,self)
    return o
end