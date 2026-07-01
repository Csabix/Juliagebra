
function start_evaluation!(self::Scheduler, model::Model)
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
            headid::Int = getGraphID(head)
            if !(headid in get_ids(self._merged_subgraph))
                push!(self._merged_roots,headid)
            end
        end

        # ? Send root Dependents for synchronization,
        # ? since they are up to date from outside modifications.
        for rootid in self._merged_roots
            put_as_w0!(sy,rootid)
        end

        # ? Assign Dependents in the schedule to workers for onNodeEval() calls.
        distribute_work!(self, model, self._mode)        
    end
end

function distribute_work!(self::Scheduler, model::Model, ::SingleFrameSingleThread)
    w::EvalWorker0 = getWorkers(model)[0]

    for nodeid in self._merged_subgraph
        put!(w,nodeid)
    end
end

function setup_localidxs!(self::Scheduler)
    empty!(self._localidxs)
    
    # ? Setup localidxs to index graphID to local idx.
    for idx in eachindex(get_ids(self._merged_subgraph)) 
        # ? self._merged_subgraph[idx] == graphID
        self._localidxs[self._merged_subgraph[idx]] = idx
    end
end

function setup_conditions_and_goals!(self::Scheduler, model::Model)
    evalGoal = length(self._merged_subgraph)
    syncGoal = 0
    empty!(self._synced)

    # ? Setup CompletedConditions, synced and syncedGoal of nodes in the merged_subgraph.
    for nodeid in self._merged_subgraph 
        node::DependentDNA = getDependentNode(model, nodeid)
        
        # ? Node is part of merged subgraph.
        reset_as_inside_node!(get_evaledcond(node))

        for parent in getGraphParents(node) 
            if !haskey(self._localidxs, getGraphID(parent)) # ? node is not part of subgraph.
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

function distribute_work!(self::Scheduler, model::Model, ::Union{SingleFrameTwoThreads, MultipleFramesSingleThread})
    w1::EvalWorkeri = getWorkers(model)[1]
    
    setup_localidxs!(self)
    setup_conditions_and_goals!(self, model)

    empty!(w1)

    for id in self._merged_subgraph
        put!(w1,id)
    end

    signal_start!(w1)
end

function get_node_weights(self::Scheduler, model::Model)::Vector{Int}
    heights::Vector{Int} = [1 for _ in self._merged_subgraph]
    
    # ? Calculate node weights based on largest height to any sink node.
    # ? Children of nodes are always later in the merged subgraph, hence the reverse.
    for idx in reverse(eachindex(get_ids(self._merged_subgraph)))
        nodeid::Int = self._merged_subgraph[idx]
        node::DependentDNA = getDependentNode(model, nodeid)
        node_height = heights[self._localidxs[nodeid]]
        
        for parent in getGraphParents(node) 
            parentid::Int = getGraphID(parent)

            if haskey(self._localidxs,parentid)
                parentidx::Int = self._localidxs[parentid]
                parent_height = heights[parentidx]
                heights[parentidx] = max(parent_height, node_height+1)
            end
        end        
    end

    return heights
end

function tag_by_weights(nodeids::Vector{Int}, weights::Vector{Int}, max_workers::Int)::Vector{Int}
    @assert length(nodeids) == length(weights) "nodeids and weights have different lengths!"
    
    # ? Which worker gets the node at idx in nodeids.
    tags::Vector{Int} = []
    
    # ? For a weight, which Worker is the next one.
    weight_next_tag::Dict{Int,Int} = Dict{Int,Int}()
        
    for idx in eachindex(nodeids)
        weight::Int = weights[idx]

        if !haskey(weight_next_tag,weight)
            weight_next_tag[weight] = 0
        else
            next_tag = weight_next_tag[weight] + 1
            weight_next_tag[weight] = (next_tag % max_workers)
        end

        # ? +1 so don't assign worker0, instead schedule [1;max_workers]
        push!(tags,weight_next_tag[weight]+1)
    end

    return tags
end

function is_topo_ordered(nodeids::Vector{Int}, model::Model)::Bool
    localidxs::Dict{Int,Int} = Dict{Int,Int}()

    # ? Get GraphID 2 local idx.
    for idx in eachindex(nodeids)
        nodeid::Int = nodeids[idx]

        @assert !haskey(localidxs, nodeid) "Dependents are not unique!"
        localidxs[nodeid] = idx
    end

    # ? Determine if all node parents are below in nodeids.
    for idx in eachindex(nodeids)
        nodeid::Int =  nodeids[idx]
        node::DependentDNA = getDependentNode(model, nodeid)

        for parent in getGraphParents(node)
            parentid::Int = getGraphID(parent)
            
            if haskey(localidxs, parentid)
                pidx = localidxs[parentid]
                if idx <= pidx
                    # ? Parent is below in the list, so topological order is violated.
                    return false
                end
            end
        end
    end

    return true
end

function sort_subgraph_by_weights(self::Scheduler, weights::Vector{Int})::Tuple{Vector{Int}, Vector{Int}}
    idxs = sortperm(weights; rev=true)
    return (get_ids(self._merged_subgraph)[idxs], weights[idxs])
end

function distribute_work!(self::Scheduler, model::Model, ::Union{SingleFrameMultipleThreads, MultipleFramesMultipleThreads})
    workers::Workers = getWorkers(model)
    
    setup_localidxs!(self)
    setup_conditions_and_goals!(self, model)
    
    for idx in 1:length(workers)
        empty!(workers[idx])
    end
    
    # ? Calculate node weights.
    heights::Vector{Int} = get_node_weights(self, model)
    @assert length(heights) == length(self._merged_subgraph) "Every node must get one weight!"

    sorted_data::Tuple{Vector{Int}, Vector{Int}} = sort_subgraph_by_weights(self, heights)
    sorted_nodeids::Vector{Int} = sorted_data[1]
    sorted_weights::Vector{Int} = sorted_data[2]
    @assert is_topo_ordered(sorted_nodeids, model) "Sorted nodeids is not in topological order!"

    # ? Assign nodes with weights to workers.
    tags::Vector{Int} = tag_by_weights(sorted_nodeids, sorted_weights, length(workers))
    @assert length(tags) == length(sorted_nodeids) "Every node must get one worker!"

    # ? Distribute work.
    for idx in eachindex(tags)
        tag::Int = tags[idx]
        put!(workers[tag],sorted_nodeids[idx])
    end

    # ? Start workers.
    for idx in 1:length(workers) 
        signal_start!(workers[idx])
    end
end