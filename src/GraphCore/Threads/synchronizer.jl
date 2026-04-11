
# ? ---------------------------------
# ! Synchronizer
# ? ---------------------------------

"""
Calls sync!() and syncAll!() on arrived Dependents.
"""
@kwdef mutable struct Synchronizer
    _internal::Queue{ObservedDNA} = Queue{ObservedDNA}()
    _external::Channel{Tuple{ObservedDNA, CompletedCondition}} = Channel{Tuple{ObservedDNA, CompletedCondition}}(100)
    _taken::Int = 0
end

Base.put!(self::Synchronizer, observed::ObservedDNA) = push!(self._internal, observed)
Base.put!(self::Synchronizer, o::ObservedDNA, c::CompletedCondition) = put!(self._external, (o, c))

function processBatch!(self::Synchronizer)
    self._taken = length(self._internal)
    observers = Set{ObserverDNA}()
    
    for _ in 1:self._taken
        d::ObservedDNA = popfirst!(self._internal)
        o::ObserverDNA = _handleSyncCall(d)
        push!(observers, o)
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

function processB!(self::Synchronizer, model::ModelDNA)
    self._taken = Base.n_avail(self._external)
    observers = Set{ObserverDNA}()

    for _ in 1:self._taken
        data::Tuple{ObservedDNA, CompletedCondition} = take!(self._external)
        d::ObservedDNA = data[0]
        o::ObserverDNA = _handleSyncCall(d)
        
        c::CompletedCondition = data[1]
        notify(c)
        increment(getScheduler(model)._syncedGoal)

        push!(observers, o)
    end

    for o in observers in 
        syncAll!(o)
    end
end