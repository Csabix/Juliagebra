
# ? ---------------------------------
# ! SyncFood
# ? ---------------------------------

struct SyncFood
    observed::ObservedDNA
    syncedIdx::Int
end

# ? ---------------------------------
# ! Synchronizer
# ? ---------------------------------

"""
Calls sync!() and syncAll!() on arrived Dependents.
"""
@kwdef mutable struct Synchronizer
    _internal::Queue{ObservedDNA} = Queue{ObservedDNA}()
    _external::Channel{SyncFood} = Channel{SyncFood}(1024)
    _taken::Int = 0
end

Base.put!(self::Synchronizer, observed::ObservedDNA) = push!(self._internal, observed)
Base.put!(self::Synchronizer, f::SyncFood) = put!(self._external, f)

function processInternal!(self::Synchronizer)
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

function processAvailableExternal!(self::Synchronizer, model::ModelDNA)
    self._taken = Base.n_avail(self._external)
    observers = Set{ObserverDNA}()

    for _ in 1:self._taken
        data::SyncFood = take!(self._external)
        d::ObservedDNA = data.observed
        o::ObserverDNA = _handleSyncCall(d)
        
        s::Scheduler = getScheduler(model)
        s._synced[data.syncedIdx] = true
        increment(s._syncedGoal)

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