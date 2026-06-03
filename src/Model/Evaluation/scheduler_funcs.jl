
function startGraphWorkers!(self::Scheduler, model::Model)
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
            if (d isa SubjectDNA) && !(d in dependentsOf(self._schedule))
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

function _distributeWork(self::Scheduler, model::Model, ::SingleFrameSingleThread)
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
        
        if d isa SubjectDNA
            # ? o is Subject, so create synced condition.
            o::SubjectDNA = d
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

function _distributeWork(self::Scheduler, model::Model, ::Union{SingleFrameTwoThreads, MultipleFramesSingleThread})
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
        od::Union{SubjectDNA,DependentDNA} = getDependent(wd[idx])

        @assert !haskey(localIDs, getGraphID(od)) "Dependents are not unique!"
        localIDs[getGraphID(od)] = idx
    end

    for idx in eachindex(wd)
        od::Union{SubjectDNA,DependentDNA} = getDependent(wd[idx])

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

function _distributeWork(self::Scheduler, model::Model, ::Union{SingleFrameMultipleThreads, MultipleFramesMultipleThreads})
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