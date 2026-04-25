
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
    _roots::Set{ObservedDNA} = Set{ObservedDNA}()
    
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

Base.schedule(self::Scheduler,dependent::DependentDNA) = isfull(self) ? (@warn "Reached Scheduler max per frame capacity, ignoring Dependent!") : push!(self._in,dependent)
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

function _setupMultiThreadedDistribution(self::Scheduler)::Tuple{Vector{WorkerFood}, Dict{Int,Int}}
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

function _distributeWork(self::Scheduler, model::ModelDNA, ::Union{SingleFrameTwoThreads, MultipleFramesSingleThread})
    w1::EvalWorkeri = getWorkers(model)[1]
    
    w1d::Vector{WorkerFood}, localIDs::Dict{Int,Int} = _setupMultiThreadedDistribution(self)

    # ? Distribute scheduling.
    put!(w1, w1d)
end

function _calculateNodeWeights(wd::Vector{WorkerFood}, localIDs::Dict{Int, Int})::Vector{Int}
    # ? Calculate node weights based on max height.
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

    return heights
end

function _assignNodesToWorkers(wd::Vector{WorkerFood}, w::Workers, heights::Vector{Int})::Vector{Int}
    # ? Which worker gets the node at idx in heights.
    tags::Vector{Int} = []
    
    # ? For a height, which Worker is the next one.
    heightTags::Dict{Int,Int} = Dict{Int,Int}()
    
    # ? For rotating between workers, which is the max.
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

    return tags
end

function _createWorkContainers(wd::Vector{WorkerFood}, w::Workers, tags::Vector{Int})::Vector{Vector{WorkerFood}}
    # ? Amount of workers, to distribute to.
    tagMax = length(w)

    # ? Vectors for each worker to complete.
    wds::Vector{Vector{WorkerFood}} = [[] for _ in 1:tagMax]
    
    for idx in eachindex(tags)
        push!(wds[tags[idx]], wd[idx])
    end

    return wds
end

function _isTopologicalOrdered(wd::Vector{WorkerFood})::Bool
    localIDs::Dict{Int,Int} = Dict{Int,Int}()
    
    # ? gather graphID -> idx
    for idx in eachindex(wd)
        od::Union{ObservedDNA,DependentDNA} = getDependent(wd[idx])
        
        @assert !haskey(localIDs, getGraphID(od)) "Dependents are not unique!"
        localIDs[getGraphID(od)] = idx 
    end

    for idx in eachindex(wd)
        od::Union{ObservedDNA,DependentDNA} = getDependent(wd[idx])

        for parent in getGraphParents(od)
            pid = getGraphID(parent)
            
            if haskey(localIDs, pid)
                pidx = localIDs[pid]
                if idx <= pidx
                    # ? Parent is below in the list, so topological order is violated.
                    return false
                end
            end
        end
    end

    return true
end

function _sortByWeight(wd::Vector{WorkerFood}, weights::Vector{Int})::Tuple{Vector{WorkerFood}, Vector{Int}}
    idxs = sortperm(weights; rev=true)
    return (wd[idxs], weights[idxs])
end

function _distributeWork(self::Scheduler, model::ModelDNA, ::Union{SingleFrameMultipleThreads, MultipleFramesMultipleThreads})
    wd::Vector{WorkerFood}, localIDs::Dict{Int,Int} = _setupMultiThreadedDistribution(self)
    w::Workers = getWorkers(model)

    # ? Calculate node weights.
    heights::Vector{Int} = _calculateNodeWeights(wd, localIDs)
    @assert length(heights) == length(wd) "Every node must get one weight!"

    wd, heights = _sortByWeight(wd, heights)
    @assert _isTopologicalOrdered(wd) "Schedule is not in topological order!"

    # ? Assign nodes with weights to workers.
    tags::Vector{Int} = _assignNodesToWorkers(wd, w, heights)
    @assert length(tags) == length(heights) "Every weight must get one worker!"

    # ? Create work containers.
    wds::Vector{Vector{WorkerFood}} = _createWorkContainers(wd, w, tags)
    @assert length(wds) == length(w) "Every worker must get a container!"

    # ? Send work.
    for idx in eachindex(wds) 
        put!(w[idx],wds[idx])
    end
end

