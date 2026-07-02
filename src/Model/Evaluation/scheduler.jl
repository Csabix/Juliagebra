
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

const SingleFrameModes = Union{SingleFrameSingleThread, SingleFrameTwoThreads, SingleFrameMultipleThreads}
const MultipleFrameModes = Union{MultipleFramesSingleThread, MultipleFramesMultipleThreads}

"""
Manages correct graph evaluation scheduling.
"""
@kwdef mutable struct Scheduler
    _in::Queue{DependentDNA} = Queue{DependentDNA}(PER_FRAME_MERGE)
    _taken::Int = 0
    _first_finish::Bool = false

    _merged_subgraph::InsertionTopoSubgraph = InsertionTopoSubgraph()
    _merged_roots::Set{Int} = Set{Int}()
    
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
get_mode(self::Scheduler)::SchedulingMode = return self._mode
is_finished(self::Scheduler)::Bool = return isReached(self._evalgoal) && isReached(self._syncgoal)
synced_node!(self::Scheduler, node::SubjectDNA) = (self._synced[getGraphID(node)]=true; increment(self._syncgoal)) 

function is_finished_first!(self::Scheduler)::Bool
    @assert is_finished(self) "Scheduler didn't finish yet!"
    
    if self._first_finish
        self._first_finish = false
        return true
    else
        return false
    end
end

function is_finished_correctly(::Scheduler, ::SingleFrameSingleThread)::Bool
    return true
end

function is_finished_correctly(self::Scheduler, ::SchedulingMode)::Bool
    for synced in values(self._synced)
        if !synced
            return false
        end
    end

    return true
end



