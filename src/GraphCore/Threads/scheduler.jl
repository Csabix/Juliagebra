
# ? ---------------------------------
# ! Scheduler
# ? ---------------------------------

const PER_FRAME_MERGE::Int = 25

abstract type SchedulingMode end
struct SingleFrameSingleThread <: SchedulingMode end
struct MultipleFramesSingleThread <: SchedulingMode end

"""
Manages correct graph evaluation scheduling.
"""
@kwdef mutable struct Scheduler
    _mode::SchedulingMode = SingleFrameSingleThread()
    _in::Queue{DependentDNA} = Queue{DependentDNA}(PER_FRAME_MERGE)
    _taken::Int = 0
    _schedule::Schedule = Schedule()
    _roots::Set{ObservedDNA} = Set{ObservedDNA}()
    
    _evaled::Vector{CompletedCondition} = Vector{CompletedCondition}()
    _evaledGoal::Goal = Goal()
    
    _synced::Vector{CompletedCondition} = Vector{CompletedCondition}()
    _syncedGoal::Goal = Goal()
end

Base.schedule(self::Scheduler,dependent::DependentDNA) = isfull(self) ? (@warn "Reached Scheduler max per frame capacity, ignoring Dependent!") : push!(self._in,dependent)
Base.isempty(self::Scheduler)::Bool = return isempty(self._in)
Base.length(self::Scheduler) = return length(self._in)
Base.isfull(self::Scheduler) = return length(self._in) == PER_FRAME_MERGE
isFinished(self::Scheduler)::Bool = return isReached(self._evaledGoal) && isReached(self._syncedGoal)
isFinishedCorrectly(self::Scheduler)::Bool = return _isFinishedCorrectly(self, self._mode)

function _isFinishedCorrectly(::Scheduler, ::SingleFrameSingleThread)::Bool
    return true
end

function _isFinishedCorrectly(self::Scheduler, ::MultipleFramesSingleThread)::Bool
    for c in self._evaled
        if !isCompleted(c)
            return false
        end
    end
        
    for c in self._synced
        if !isCompleted(c)
            return false
        end
    end

    Base.resize!(self._evaled,0)
    Base.resize!(self._synced,0)

    return true
end

function startGraphWorkers!(self::Scheduler, model::ModelDNA)
    sy::Synchronizer = getSynchronizer(model)
    
    self._taken = length(self)
    heads::Set{DependentDNA} = Set{DependentDNA}()
    schedules::Vector{Schedule} = []

    for _ in 1:self._taken
        d::DependentDNA = popfirst!(self._in)
        push!(schedules,getSchedule(d))
        push!(heads,d)
    end

    if !isempty(schedules)
        # TODO: maybe copy to avoid GC?
        self._schedule = merge(schedules)
        
        # ? Filter out heads, which are not in the schedules.
        empty!(self._roots)
        for d in heads
            if (d isa ObservedDNA) && !(d in dependentsOf(self._schedule))
                push!(self._roots,d)
            end
        end

        # ? Send root Dependents for synchronization,
        # ? since they are up to date from outside modifications.
        for d in self._roots
            put!(sy,d)
        end

        # ? Assign Dependents in the schedule to workers for onNodeEval() calls.
        _distributeWork(self, model, self._mode)        
    end
end

function _distributeWork(self::Scheduler, model::ModelDNA, ::SingleFrameSingleThread)
    w::EvalWorker0 = getWorkers(model)[0]
    
    for d in self._schedule
        put!(w,d)
    end
end

function _distributeWork(self::Scheduler, model::ModelDNA, ::MultipleFramesSingleThread)
    w1::EvalWorkeri = getWorkers(model)[1]
    
    evaledGoal = length(self._schedule)
    syncedGoal = length(self._roots)

    # ? Reset condition containers.
    # TODO: Dynamically size and reset.
    Base.resize!(self._evaled,0)
    Base.resize!(self._synced,0)
    
    localIDs = Dict{Int,Int}()
    w1d::Vector{WorkerFood} = []

    # ? Prepare scheduling distribution.
    for idx in 1:length(self._schedule) 
        d::DependentDNA = self._schedule[idx]
        
        # ? Collect parents's CompletedConditions.
        conditions::Vector{CompletedCondition} = []
        for parent in getGraphParents(d) 
            id = getGraphID(parent)

            if haskey(localIDs, id)
                push!(conditions, self._evaled[localIDs[id]])
            end
        end 
        
        # ? Create dependent's evaled CompletedCondition.
        localIDs[getGraphID(d)] = idx
        evaled = CompletedCondition()
        push!(self._evaled, evaled)
        
        if d isa ObservedDNA
            # ? o is Observed, so create synced condition.
            o::ObservedDNA = d
            syncedGoal+=1
            synced = CompletedCondition()
            push!(self._synced, synced)

            push!(w1d, WorkerFood(conditions, (o, synced), evaled))
        else
            push!(w1d, WorkerFood(conditions, d, evaled))
        end
    end

    # ? Reset goals.
    reset!(self._evaledGoal, evaledGoal)
    reset!(self._syncedGoal, syncedGoal)
    
    @assert length(self._schedule) == length(self._evaled) "Not enough conditions were created..."
    @assert length(self._schedule) == length(localIDs) "Not enough parent conditions were assigned!"

    # ? Distribute scheduling.
    put!(w1, w1d)
end

