
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
    _schedule::Schedule = Schedule()
    _roots::Set{SubjectDNA} = Set{SubjectDNA}()
    
    _evaled::Vector{CompletedCondition} = Vector{CompletedCondition}()
    _evaledGoal::AtomicGoal = AtomicGoal()
    
    _synced::Vector{Bool} = Vector{Bool}()
    _syncedGoal::Goal = Goal()

    _mode::SchedulingMode = SingleFrameSingleThread()
    _modes::Vector{SchedulingMode} = [
        SingleFrameSingleThread(),
        SingleFrameTwoThreads(),
        SingleFrameMultipleThreads(),
        MultipleFramesSingleThread(),
        MultipleFramesMultipleThreads()
    ]
end

Base.schedule(self::Scheduler,dependent::DependentDNA) = isfull(self) ? (@warn "Reached Scheduler max per frame capacity, ignoring Dependent!") : (all(x -> x !== dependent, self._in) && push!(self._in,dependent))
Base.isempty(self::Scheduler)::Bool = return isempty(self._in)
Base.length(self::Scheduler) = return length(self._in)
Base.isfull(self::Scheduler) = return length(self._in) == PER_FRAME_MERGE
isFinished(self::Scheduler)::Bool = return isReached(self._evaledGoal) && isReached(self._syncedGoal)
isFinishedCorrectly!(self::Scheduler)::Bool = return _isFinishedCorrectly!(self, self._mode)
isFinishedFirst(self::Scheduler)::Bool = return length(self._evaled)!=0 && length(self._synced)!=0
setMode(self::Scheduler, idx::Int) = self._mode = self._modes[idx]
getMode(self::Scheduler, idx::Int)::SchedulingMode = return self._modes[idx]
getModesLength(self::Scheduler)::Int = return length(self._modes)


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



