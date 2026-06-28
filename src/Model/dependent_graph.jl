# ? ---------------------------------
# ! DependentGraph
# ? ---------------------------------

@kwdef mutable struct DependentGraph
    _dependents::Vector{DependentDNA} = Vector{DependentDNA}()
end

getNodes(self::DependentGraph)::Vector{DependentDNA} = return self._dependents
Base.empty!(self::DependentGraph) = empty!(self._dependents)

function add!!(self::DependentGraph,new_node::T) where T<:DependentDNA
    new_node_dependent = _Dependent_(new_node)
    new_node_dependent._graphID = length(self._dependents) + 1
    
    for node in self._dependents
        node_subgraph = get_subgraph(node)
        for parent in new_node_dependent._graphParents
            @assert !isUnbuilt(parent) "Parent must be built!"
            if (parent === node) || (getGraphID(parent) in get_ids(node_subgraph))
                enchain!(node_subgraph,new_node)
                break
            end
        end
    end
    
    push!(self._dependents,new_node)
end

function _getDependentNode(self::DependentGraph, graphID::Integer)::DependentDNA
    return self._dependents[graphID]
end
