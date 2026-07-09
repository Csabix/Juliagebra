
# ? ---------------------------------
# ! InsertionTopoSubgraph
# ? ---------------------------------

"""
The graphIDs of nodes reachable from a root are stored in InsertionTopoSubgraph.
- Nodes are stored in insertion order.
- The vector forms a topological order conforming to dependency constraints.
"""
@kwdef struct InsertionTopoSubgraph
    _ids::Vector{Int} = Vector{Int}() # ? Vector of graphIDs.
end

Base.length(self::InsertionTopoSubgraph) = return length(self._ids)
Base.isempty(self::InsertionTopoSubgraph) = return isempty(self._ids)
Base.getindex(self::InsertionTopoSubgraph, idx::Int)::Int = return self._ids[idx]
Base.iterate(self::InsertionTopoSubgraph, state=1) = state<=length(self) ? (return (self._ids[state],state+1)) : (return nothing)
get_ids(self::InsertionTopoSubgraph)::Vector{Int} = return self._ids
get_set(self::InsertionTopoSubgraph)::Set{Int} = return Set(self._ids)

function enchain!(self::InsertionTopoSubgraph, id::Int)
    @assert (length(self)>0) ? (id>self._ids[end]) : true "IDs must be increasing!"
    push!(self._ids,id)
end

function enchain!(self::InsertionTopoSubgraph, item::DependentDNA)
    id::Int = getGraphID(item)
    enchain!(self,id)
end

function Base.merge(s1::InsertionTopoSubgraph, s2::InsertionTopoSubgraph)::InsertionTopoSubgraph
    s = InsertionTopoSubgraph()
    idx1 = 1
    idx2 = 1
    len1 = length(s1)
    len2 = length(s2)

    while (idx1<=len1) && (idx2<=len2)        
        id1 = s1[idx1]
        id2 = s2[idx2]
        
        if (id1 < id2)
            enchain!(s,id1)
            idx1+=1
        elseif (id1 > id2)
            enchain!(s,id2)
            idx2+=1
        else # ? id1 == id2
            @assert id1 === id2 "IDs must be equal!"
            enchain!(s,id1)
            idx1+=1
            idx2+=1
        end
    end

    while (idx1<=len1)
        enchain!(s,s1[idx1])
        idx1+=1
    end 
        
    while (idx2<=len2)
        enchain!(s,s2[idx2])
        idx2+=1
    end

    return s
end

Base.merge(schedules::Vector{InsertionTopoSubgraph})::InsertionTopoSubgraph = return foldl(Base.merge,schedules)

Base.copy!(dst::InsertionTopoSubgraph, src::InsertionTopoSubgraph) = copy!(dst._ids, src._ids)

function is_topo_ordered(nodeids::Vector{Int}, nodes::Vector{DependentDNA})::Bool
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
        node::DependentDNA = nodes[nodeid]

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