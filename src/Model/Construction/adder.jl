
# ? ---------------------------------
# ! Adder
# ? ---------------------------------

const ADDER_IN_CHANNEL_SIZE = 8192

"""
Calls added! and addedAll! calls on built Dependents if needed.
"""
@kwdef mutable struct Adder
    _in::Channel{SubjectDNA} = Channel{SubjectDNA}(ADDER_IN_CHANNEL_SIZE)
end

destroy!(self::Adder) = close(self._in)
Base.put!(self::Adder,o::SubjectDNA) = put!(self._in,o)
Base.isempty(self::Adder)::Bool = return isempty(self._in)

# Green Thread
function process_avail!(self::Adder; send_log::Bool=true)::Bool
    takeNum = Base.n_avail(self._in)
    addedAllSet = Set{ObserverDNA}()

    for i in 1:takeNum
        subject::SubjectDNA = take!(self._in)
        observer::ObserverDNA = getObserver(subject)

        added!(observer,subject)
        _setHasInstance!(observer)

        push!(addedAllSet,observer)
    end
    
    for observer in addedAllSet        
        # ? Must call addedAll!
        addedAll!(observer)
    end

    if send_log && takeNum > 1
        @log "Built $(takeNum)!"
    end
    return takeNum > 0
end

