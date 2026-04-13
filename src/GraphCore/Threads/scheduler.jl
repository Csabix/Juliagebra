
# ? ---------------------------------
# ! Scheduler
# ? ---------------------------------

const PER_FRAME_MERGE::Int = 25

abstract type SchedulingMode end
struct SingleFrameSingleThread <: SchedulingMode end
struct MultipleFramesSingleThread <: SchedulingMode end
struct MultipleFramesMultipleThreads <: SchedulingMode end


"""
Manages correct graph evaluation scheduling.
"""
@kwdef mutable struct Scheduler
    _in::Queue{DependentDNA} = Queue{DependentDNA}(PER_FRAME_MERGE)
    _taken::Int = 0
    _schedule::Schedule = Schedule()
    _roots::Set{ObservedDNA} = Set{ObservedDNA}()
    
    _evaled::Vector{CompletedCondition} = Vector{CompletedCondition}()
    _evaledGoal::AtomicGoal = AtomicGoal()
    
    _synced::Vector{Bool} = Vector{Bool}()
    _syncedGoal::Goal = Goal()

    _mode::SchedulingMode = SingleFrameSingleThread()
    _modes::Vector{SchedulingMode} = [
        SingleFrameSingleThread(),
        MultipleFramesSingleThread(),
        MultipleFramesMultipleThreads()
    ]
    _scheduled::Vector{Int} = [0 for _ in 1:8]
end

Base.schedule(self::Scheduler,dependent::DependentDNA) = isfull(self) ? (@warn "Reached Scheduler max per frame capacity, ignoring Dependent!") : push!(self._in,dependent)
Base.isempty(self::Scheduler)::Bool = return isempty(self._in)
Base.length(self::Scheduler) = return length(self._in)
Base.isfull(self::Scheduler) = return length(self._in) == PER_FRAME_MERGE
isFinished(self::Scheduler)::Bool = return isReached(self._evaledGoal) && isReached(self._syncedGoal)
isFinishedCorrectly(self::Scheduler)::Bool = return _isFinishedCorrectly(self, self._mode)
setMode(self::Scheduler, idx::Int) = self._mode = self._modes[idx]

function _isFinishedCorrectly(::Scheduler, ::SingleFrameSingleThread)::Bool
    return true
end

function _isFinishedCorrectly(self::Scheduler, ::Union{MultipleFramesSingleThread,MultipleFramesMultipleThreads})::Bool
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
    
    w1d::Vector{WorkerFood}, localIDs::Dict{Int,Int} = _setupDistribution(self)

    # ? Distribute scheduling.
    put!(w1, w1d)
end

function _distributeWork(self::Scheduler, model::ModelDNA, ::MultipleFramesMultipleThreads)
    wd::Vector{WorkerFood}, localIDs::Dict{Int,Int} = _setupDistribution(self)


    # ? Calculate node max height.
    heights::Vector{Int} = [1 for _ in wd]
    for idx in reverse(eachindex(wd))
        d::DependentDNA = getDependent(wd[idx])
        height = heights[localIDs[getGraphID(d)]]
        
        for parent in getGraphParents(d) 
            id = getGraphID(parent)

            if haskey(localIDs,id)
                _height = heights[localIDs[id]]
                heights[localIDs[id]] = max(_height, height+1)
            end
        end        
    end

    w::Workers = getWorkers(model)
    
    # ? Assign nodes to workers.
    heightTags::Dict{Int,Int} = Dict{Int,Int}()
    tags::Vector{Int} = []
    tagMax = length(w)
    for idx in eachindex(wd)
        height = heights[idx]

        if !haskey(heightTags,height)
            heightTags[height] = 0
        else
            _height = heightTags[height] + 1
            heightTags[height] = (_height % tagMax)
        end

        push!(tags,heightTags[height]+1)
    end

    # ? Create work containers.
    wds::Vector{Vector{WorkerFood}} = [[] for _ in 1:tagMax]
    for idx in eachindex(tags)
        push!(wds[tags[idx]], wd[idx])
    end

    # ? Send work.
    for idx in 1:tagMax 
        self._scheduled[idx] = length(wds[idx])
        put!(w[idx],wds[idx])
    end
end

function _setupDistribution(self::Scheduler)::Tuple{Vector{WorkerFood}, Dict{Int,Int}}
    evaledGoal = length(self._schedule)
    syncedGoal = 0

    # ? Reset condition containers.
    # TODO: Dynamically size and reset.
    Base.resize!(self._evaled,0)
    Base.resize!(self._synced,0)
    
    localIDs = Dict{Int,Int}()
    wd::Vector{WorkerFood} = []

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
            push!(self._synced, false)

            push!(wd, WorkerFood(conditions, SyncFood(o, length(self._synced)), evaled))
        else
            push!(wd, WorkerFood(conditions, d, evaled))
        end
    end

    # ? Reset goals.
    reset!(self._evaledGoal, evaledGoal)
    reset!(self._syncedGoal, syncedGoal)
    
    @assert length(self._schedule) == length(self._evaled) "Not enough conditions were created..."
    @assert length(self._schedule) == length(localIDs) "Not enough parent conditions were assigned!"
    @assert length(self._synced) == syncedGoal "Goal is inconsistent!"

    return (wd, localIDs)
end

