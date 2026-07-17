
# ? ---------------------------------
# ! Adder
# ? ---------------------------------

const ADDER_IN_CHANNEL_SIZE = 8192

"""
Last stage of Construction pipeline.
- Runs on App main-thread.
- Sets the starting state of nodes.
- Calls added! addedAll! events on subject-observers.
"""
@kwdef mutable struct Adder
    _in::Channel{DependentDNA} = Channel{DependentDNA}(ADDER_IN_CHANNEL_SIZE)
end

destroy!(self::Adder) = close(self._in)
Base.put!(self::Adder,o::DependentDNA) = put!(self._in,o)
Base.isempty(self::Adder)::Bool = return isempty(self._in)


function process_avail!(self::Adder; send_log::Bool=true, ms_limit::Float64=33.333)::Bool
    # TODO: Have @invokelatest consume this whole function, if needed.

    avail = Base.n_avail(self._in)
    taken = 0
    observers = Set{ObserverDNA}()

    ns_limit::UInt64 = ms_to_ns(ms_limit)
    start_time::UInt64 = time_ns()
    for i in 1:avail
        process_item!(self, take!(self._in), observers)
        taken+=1
        # println(taken)

        # ? Check if ms limit is reached.
        if time_ns() - start_time > ns_limit
           break 
        end
    end
    
    for observer in observers        
        # ? Call addedAll! events.
        addedAll!(observer)
    end

    if send_log && taken > 1
        @log "Built $(taken)!"
    end

    return taken > 0
end

function process_item!(::Adder, dependent::DependentDNA, ::Set{ObserverDNA})
    @invokelatest node_start!(dependent)
end

function process_item!(self::Adder, subject::SubjectDNA, observers::Set{ObserverDNA})
    @invokelatest node_start!(subject)

    # ? Call added! event.
    observer::ObserverDNA = getObserver(subject)
    added!(observer,subject)
    _setHasInstance!(observer)

    push!(observers, observer)
end