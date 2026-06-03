# ? ---------------------------------
# ! DependentGraph
# ? ---------------------------------

@kwdef mutable struct DependentGraph
    _dependentObjects::Vector{DependentDNA} = Vector{DependentDNA}()
end

getNodes(self::DependentGraph) = return self._dependentObjects
Base.empty!(self::DependentGraph) = empty!(self._dependentObjects)

function add!!(self::DependentGraph,asset::T) where T<:DependentDNA
    assetDependent = _Dependent_(asset)
    assetDependent._graphID = length(self._dependentObjects) + 1
    
    for graphItem in self._dependentObjects
        graphItemChain = getSchedule(graphItem)
        for assetParent in assetDependent._graphParents
            if (assetParent === graphItem) || (assetParent in dependentsOf(graphItemChain))
                enchain!(graphItemChain,asset)
                break
            end
        end
    end
    
    push!(self._dependentObjects,asset)
end

function Base.getindex(self::DependentGraph, _pickedID::Integer)::DependentDNA
    return self._dependentObjects[_pickedID - ID_LOWER_BOUND]
end

function getDependent(self::DependentGraph, graphID::Int)::DependentDNA
    return self._dependentObjects[graphID]
end

function to_string(self::DependentGraph)
    outStr = ""

    for dependent in self._dependentObjects
        outStr *= "$(to_string(dependent))\n"
    end

    outStr = outStr[1:end-1]

    return outStr
end