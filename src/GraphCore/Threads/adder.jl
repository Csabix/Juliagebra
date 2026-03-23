
# ? ---------------------------------
# ! Adder
# ? ---------------------------------

const ADDER_IN_CHANNEL_SIZE = 100

"""
Calls added! and addedAll! calls on built Dependents if needed.
"""
@kwdef mutable struct Adder
    _in::Channel{DependentDNA} = Channel{DependentDNA}(ADDER_IN_CHANNEL_SIZE)
end

destroy!(self::Adder) = close(self._in)
Base.put!(self::Adder,d::DependentDNA) = put!(self._in,d)
Base.isempty(self::Adder)::Bool = return isempty(self._in)

# Green Thread
function processBatch!(self::Adder, ::AppDNA)
    takeNum = Base.n_avail(self._in)
    addedAllSet = Set{ObserverDNA}()
    
    for i in 1:takeNum
        dependent = take!(self._in)
        observer = _handleAddedCalls(dependent)

        if !isnothing(observer)
            # ? An Observer was assigned to this dependent.
            push!(addedAllSet,observer)
        end
    end
    
    for observer in addedAllSet        
        # ? Must call addedAll! and activate!
        addedAll!(observer)
    end

    if takeNum > 1
        @log "Built $(takeNum)!"
    end
end

# Green Thread
function _handleAddedCalls(::DependentDNA)
    # ? The BLUE Thread already did the required building work.
    return nothing
end

# Green Thread
function _handleAddedCalls(observed::ObservedDNA)
    observer = getObserver(observed)
    added!(observer,observed)
    _setHasInstance!(observer)
    return observer
end