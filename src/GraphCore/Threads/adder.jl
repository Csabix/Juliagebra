
# ? ---------------------------------
# ! Adder
# ? ---------------------------------

const ADDER_IN_CHANNEL_SIZE = 100

"""
Calls added! and addedAll! calls on built Dependents if needed.
"""
@kwdef mutable struct Adder
    _in::Channel{ObservedDNA} = Channel{ObservedDNA}(ADDER_IN_CHANNEL_SIZE)
end

destroy!(self::Adder) = close(self._in)
Base.put!(self::Adder,o::ObservedDNA) = put!(self._in,o)
Base.isempty(self::Adder)::Bool = return isempty(self._in)

# Green Thread
function processBatch!(self::Adder)
    takeNum = Base.n_avail(self._in)
    addedAllSet = Set{ObserverDNA}()
    
    for i in 1:takeNum
        observed::ObservedDNA = take!(self._in)
        observer::ObserverDNA = getObserver(observed)

        added!(observer,observed)
        _setHasInstance!(observer)

        push!(addedAllSet,observer)
    end
    
    for observer in addedAllSet        
        # ? Must call addedAll!
        addedAll!(observer)
    end

    if takeNum > 1
        @log "Built $(takeNum)!"
    end
end

