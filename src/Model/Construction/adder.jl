
# ? ---------------------------------
# ! Adder
# ? ---------------------------------

const ADDER_IN_CHANNEL_SIZE = 8192

"""
Calls added! and addedAll! calls on built Dependents if needed.
"""
@kwdef mutable struct Adder
    _in::Channel{DependentDNA} = Channel{DependentDNA}(ADDER_IN_CHANNEL_SIZE)
end

destroy!(self::Adder) = close(self._in)
Base.put!(self::Adder,o::DependentDNA) = put!(self._in,o)
Base.isempty(self::Adder)::Bool = return isempty(self._in)


function process_avail!(self::Adder; send_log::Bool=true)::Bool
    takeNum = Base.n_avail(self._in)
    observers = Set{ObserverDNA}()

    for i in 1:takeNum
        process_item!(self, take!(self._in), observers)
    end
    
    for observer in observers        
        # ? Call addedAll! events.
        addedAll!(observer)
    end

    if send_log && takeNum > 1
        @log "Built $(takeNum)!"
    end

    return takeNum > 0
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