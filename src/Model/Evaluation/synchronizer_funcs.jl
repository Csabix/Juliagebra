
function process_w0_avail!(self::Synchronizer)
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

function process_wi_avail!(self::Synchronizer, model::Model)::Bool
    
    # TODO: Continue Here.
    
    taken = Base.n_avail(self._wi_nodes)
    self._taken += taken
    observers = Set{ObserverDNA}()

    for _ in 1:taken
        process_wi_item!(self,model,observers)
    end

    for o in observers in 
        syncAll!(o)
    end
    
    return taken > 0
end

function processUntilFinishedExternal!(self::Synchronizer, model::Model)
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

function process_wi_item!(self::Synchronizer, model::Model, observers::Set{ObserverDNA})
    s::SubjectDNA = take!(self._external)
    o::ObserverDNA = getObserver(s)
    
    # ? Call sync! event.
    sync!(o,s)
    
    # ? Tell Scheduler sync! event happend.
    synced_node!(getScheduler(model), s)

    push!(observers, o)
end