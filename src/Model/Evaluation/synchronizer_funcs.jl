
function process_w0_avail!(self::Synchronizer, model::Model)
    empty!(self._observers)
    self._taken = length(self._w0_nodeids) # ? resets _taken field for other process_* functions!

    for _ in 1:self._taken
        id::Int = popfirst!(self._w0_nodeids)
        d::SubjectDNA = getDependentNode(model, id)
        o::ObserverDNA = getObserver(d)
        sync!(o,d)

        push!(self._observers, o)
    end

    for o in self._observers in 
        syncAll!(o)
    end
end

function process_wi_avail!(self::Synchronizer, model::Model)::Bool
    empty!(self._observers)
    taken = Base.n_avail(self._wi_nodeids)
    self._taken += taken

    for _ in 1:taken
        process_wi_item!(self,model)
    end

    for o in self._observers in 
        syncAll!(o)
    end
    
    return taken > 0
end

function process_wi_until_finish!(self::Synchronizer, model::Model)
    empty!(self._observers)
    s::Scheduler = getScheduler(model)

    while !isReached(s._syncgoal)
        process_wi_item!(self,model)
        self._taken += 1
    end

    wait(s._evalgoal)

    @assert is_finished(s) "Scheduler must be finished here!"

    for o in self._observers in 
        syncAll!(o)
    end
end

function process_wi_item!(self::Synchronizer, model::Model)
    id::Int = take!(self._wi_nodeids) # ? take! waits for id to come in.
    s::SubjectDNA = getDependentNode(model, id)
    o::ObserverDNA = getObserver(s)
    
    # ? Call sync! event.
    sync!(o,s)
    
    # ? Tell Scheduler sync! event happend.
    synced_node!(getScheduler(model), s)

    # ? Store observer for syncAll!
    push!(self._observers, o)
end