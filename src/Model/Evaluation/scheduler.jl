
# ? ---------------------------------
# ! Scheduler
# ? ---------------------------------

const PER_FRAME_MERGE::Int = 25

abstract type SchedulingMode end

struct SingleFrameSingleThread <: SchedulingMode end
Base.string(::SingleFrameSingleThread) = "Single Frame - Single Threaded"

struct SingleFrameTwoThreads <: SchedulingMode end
Base.string(::SingleFrameTwoThreads) = "Single Frame - Two Threaded"

struct SingleFrameMultipleThreads <: SchedulingMode end
Base.string(::SingleFrameMultipleThreads) = "Single Frame - Multi Threaded"

struct MultipleFramesSingleThread <: SchedulingMode end
Base.string(::MultipleFramesSingleThread) = "Multiple Frames - Single Threaded"

struct MultipleFramesMultipleThreads <: SchedulingMode end
Base.string(::MultipleFramesMultipleThreads) = "Multiple Frames - Multi Threaded"



"""
Manages correct graph evaluation scheduling.
"""
@kwdef mutable struct Scheduler
    _in::Queue{DependentDNA} = Queue{DependentDNA}(PER_FRAME_MERGE)
    _taken::Int = 0
    
    _merged_subgraph::InsertionTopoSubgraph = InsertionTopoSubgraph()
    _merged_roots::Set{DependentDNA} = Set{DependentDNA}()
    
    _localidxs::Dict{Int,Int} = Dict{Int,Int}() # ? graphID 2 local idxs.
    _synced::Dict{Int,Bool} = Dict{Int,Bool}() # ? graphID 2 is synced.
    
    _evalgoal::AtomicGoal = AtomicGoal()
    _syncgoal::Goal = Goal()

    _mode::SchedulingMode = SingleFrameSingleThread()
    _modes::Vector{SchedulingMode} = [
        SingleFrameSingleThread(),
        SingleFrameTwoThreads(),
        SingleFrameMultipleThreads(),
        MultipleFramesSingleThread(),
        MultipleFramesMultipleThreads()
    ]
end

Base.schedule(self::Scheduler,dependent::DependentDNA) = isfull(self) ? (@warn "Reached Scheduler max per frame capacity, ignoring Dependent!") : push!(self._in,dependent)
Base.isempty(self::Scheduler)::Bool = return isempty(self._in)
Base.length(self::Scheduler) = return length(self._in)
Base.isfull(self::Scheduler) = return length(self._in) == PER_FRAME_MERGE
setMode(self::Scheduler, idx::Int) = self._mode = self._modes[idx]
getMode(self::Scheduler, idx::Int)::SchedulingMode = return self._modes[idx]
getModesLength(self::Scheduler)::Int = return length(self._modes)
isFinished(self::Scheduler)::Bool = return isReached(self._evalgoal) && isReached(self._syncgoal)
isFinishedCorrectly!(self::Scheduler)::Bool = return _isFinishedCorrectly!(self, self._mode)
isFinishedFirst(self::Scheduler)::Bool = return length(self._evaled)!=0 && length(self._synced)!=0


function _isFinishedCorrectly!(::Scheduler, ::SingleFrameSingleThread)::Bool
    return true
end

function _isFinishedCorrectly!(self::Scheduler, ::SchedulingMode)::Bool
    @assert isFinishedFirst(self) "Not first finish!"
    
    for c in self._evaled
        if !isCompleted(c)
            return false
        end
    end
        
    for c in self._synced
        if c == false
            return false
        end
    end

    Base.resize!(self._evaled,0)
    Base.resize!(self._synced,0)

    return true
end



