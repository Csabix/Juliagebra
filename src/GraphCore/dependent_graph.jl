# ? ---------------------------------
# ! DependentGraph
# ? ---------------------------------

@kwdef mutable struct DependentGraph <: DependentGraphDNA
    _dependentObjects::Vector{DependentDNA} = Vector{DependentDNA}()
end

_DependentGraph_(self::DependentGraphDNA)::DependentGraph = error("Missing \"_DependentGraph_\" func for type of \"$(typeof(self))\"!")
_DependentGraph_(self::DependentGraph)::DependentGraph = return self

getNodes(self::DependentGraphDNA) = return _DependentGraph_(self)._dependentObjects

function Base.empty!(self::DependentGraphDNA)
    g::DependentGraph =_DependentGraph_(self)
    empty!(g._dependentObjects)
end

function add!!(self::DependentGraphDNA,asset::T) where T<:DependentDNA
    
    graph = _DependentGraph_(self)
    assetDependent = _Dependent_(asset)
    assetDependent._graphID = length(graph._dependentObjects) + 1 + ID_LOWER_BOUND
    
    for graphItem in graph._dependentObjects
        graphItemChain = getSchedule(graphItem)
        for assetParent in assetDependent._graphParents
            if (assetParent in dependentsOf(graphItemChain)) || assetParent === graphItem
                enchain!(graphItemChain,asset)
                break
            end
        end
    end
    
    push!(graph._dependentObjects,asset)
end

function Base.getindex(self::DependentGraphDNA,id::Integer)::DependentDNA
    graph = _DependentGraph_(self)
    return graph._dependentObjects[id - ID_LOWER_BOUND]
end

function to_string(self::DependentGraphDNA)
    graph = _DependentGraph_(self)
    outStr = ""

    for dependent in graph._dependentObjects
        outStr *= "$(to_string(dependent))\n"
    end

    outStr = outStr[1:end-1]

    return outStr
end