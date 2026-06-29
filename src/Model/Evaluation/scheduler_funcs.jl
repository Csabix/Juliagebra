
function startGraphWorkers!(self::Scheduler, model::Model)
    sy::Synchronizer = getSynchronizer(model)
    
    self._taken = length(self)
    heads::Set{DependentDNA} = Set{DependentDNA}()
    subgraphs::Vector{InsertionTopoSubgraph} = []

    for _ in 1:self._taken
        head::DependentDNA = popfirst!(self._in)
        push!(subgraphs,get_subgraph(head))
        push!(heads,head)
    end

    if !isempty(subgraphs)
        copy!(self._merged_subgraph, merge(subgraphs))
        
        # ? Filter out heads, which are not in the merged subgraph.
        empty!(self._merged_roots)
        for head in heads
            if !(getGraphID(head) in get_ids(self._merged_subgraph))
                push!(self._merged_roots,head)
            end
        end

        # ? Send root Dependents for synchronization,
        # ? since they are up to date from outside modifications.
        for root in self._merged_roots
            put!(sy,root)
        end

        # ? Assign Dependents in the schedule to workers for onNodeEval() calls.
        _distributeWork(self, model, self._mode)        
    end
end

function _distributeWork(self::Scheduler, model::Model, ::SingleFrameSingleThread)
    w::EvalWorker0 = getWorkers(model)[0]

    for nodeid in self._merged_subgraph
        put!(w,nodeid)
    end
end

function setup_multithreaded_environment!(self::Scheduler, model::Model)
    evalGoal = length(self._merged_subgraph)
    syncGoal = 0

    # ? Setup localidxs to index graphID to local idx.
    empty!(self._localidxs)
    for idx in eachindex(get_ids(self._merged_subgraph)) 
        # ? self._merged_subgraph[idx] == graphID
        self._localidxs[self._merged_subgraph[idx]] = idx
    end

    # ? Setup CompletedConditions, synced and syncedGoal of nodes.
    empty!(self._synced)
    for nodeid in self._merged_subgraph 
        node::DependentDNA = getDependentNode(model, nodeid)
        
        # ? Node is part of merged subgraph.
        reset_as_inside_node!(get_evaledcond(node))

        for parent in getGraphParents(node) 
            if !haskey(self._localidxs, nodeid) # ? node is not part of subgraph.
                reset_as_outside_parent!(get_evaledcond(parent))
            end
        end

        if (node isa SubjectDNA) # ? node will be sent to Synchronizer.
            syncGoal += 1
            self._synced[nodeid] = false    
        end
    end

    reset!(self._evalgoal, evalGoal)
    reset!(self._syncgoal, syncGoal) 
        
    @assert length(self._merged_subgraph) == length(self._localidxs) "Not all nodes in subgraph have localidx!"
    @assert length(self._synced) == syncGoal "Goal is inconsistent!"
end

function _distributeWork(self::Scheduler, model::Model, ::Union{SingleFrameTwoThreads, MultipleFramesSingleThread})
    w1::EvalWorkeri = getWorkers(model)[1]
    
    setup_multithreaded_environment!(self, model)

    # TODO: Continue here.

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
    @assert _isTopologicalOrdered(wd) "Work is not in topological order!"

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