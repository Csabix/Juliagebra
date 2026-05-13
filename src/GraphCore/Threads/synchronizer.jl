
# ? ---------------------------------
# ! SyncFood
# ? ---------------------------------

struct SyncFood
    subject::SubjectDNA
    syncedIdx::Int
end

# ? ---------------------------------
# ! Synchronizer
# ? ---------------------------------

"""
Calls sync!() and syncAll!() on arrived Dependents.
"""
@kwdef mutable struct Synchronizer
    _internal::Queue{SubjectDNA} = Queue{SubjectDNA}()
    _external::Channel{SyncFood} = Channel{SyncFood}(8192)
    _taken::Int = 0
end

Base.put!(self::Synchronizer, subject::SubjectDNA) = push!(self._internal, subject)
Base.put!(self::Synchronizer, f::SyncFood) = put!(self._external, f)

function processInternal!(self::Synchronizer)
    self._taken = length(self._internal)
    observers = Set{ObserverDNA}()

    for _ in 1:self._taken
        d::SubjectDNA = popfirst!(self._internal)
        o::ObserverDNA = getObserver(d)
        sync!(o,d)

        push!(observers, o)
    end

    for o in observers in 
        syncAll!(o)
    end
end

function processAvailableExternal!(self::Synchronizer, model::ModelDNA)
    taken = Base.n_avail(self._external)
    self._taken += taken
    observers = Set{ObserverDNA}()

    for _ in 1:taken
        _processExternal!(self,model,observers)
    end

    for o in observers in 
        syncAll!(o)
    end
end

function processUntilFinishedExternal!(self::Synchronizer, model::ModelDNA)
    observers = Set{ObserverDNA}()
    s::Scheduler = getScheduler(model)

    while !isReached(s._syncedGoal)
        _processExternal!(self,model,observers)
        self._taken += 1
    end

    wait(s._evaledGoal)

    @assert isFinished(s) "Scheduler must be finished here!"

    for o in observers in 
        syncAll!(o)
    end
end

function _processExternal!(self::Synchronizer, model::ModelDNA, observers::Set{ObserverDNA})
    data::SyncFood = take!(self._external)
    o::ObserverDNA = getObserver(data.subject)
    sync!(o,data.subject)
        
    s::Scheduler = getScheduler(model)
    s._synced[data.syncedIdx] = true
    increment(s._syncedGoal)

    push!(observers, o)
end
