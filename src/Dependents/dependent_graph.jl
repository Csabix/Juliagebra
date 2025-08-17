mutable struct DependentGraph <: DependentGraphDNA
    _dependentObjects::Vector{DependentDNA}

    function DependentGraph()
        new(Vector{DependentDNA}())
    end

end

# TODO: idotol valo fugges, timestep alapu osszefesulessel
# TODO: Renderers should be placed at the fixed end of the graph, for safe and single renderupdate.

function add!!(self::DependentGraphDNA,asset::T) where T<:DependentDNA
    
    graph = _DependentGraph_(self)
    assetDependent = _Dependent_(asset)

    for graphItem in graph._dependentObjects
        graphItemChain = _Dependent_(graphItem)._graphChain
        for assetParent in assetDependent._graphParents
            if (assetParent in graphItemChain) || assetParent === graphItem
                push!(graphItemChain,asset)
                break
            end
        end
    end
    
    push!(graph._dependentObjects,asset)
    assetDependent._graphID = length(graph._dependentObjects) + ID_LOWER_BOUND
end

function fetch(self::DependentGraphDNA,id::Integer)::DependentDNA
    graph = _DependentGraph_(self)
    return graph._dependentObjects[id - ID_LOWER_BOUND]
end

_DependentGraph_(self::DependentGraphDNA)::DependentGraph = error("Missing \"_DependentGraph_\" func for type of \"$(typeof(self))\"!")
_DependentGraph_(self::DependentGraph)::DependentGraph = return self