mutable struct DependentGraph
    _shrd::SharedData
    _dependentObjects::Vector{DependentDNA}

    function DependentGraph(shrd::SharedData)
        new(shrd,Vector{DependentDNA}())
    end

end

# TODO: idotol valo fugges, timestep alapu osszefesulessel
# TODO: Renderers should be placed at the fixed end of the graph, for safe and single renderupdate.

function add!!(self::DependentGraph,asset::T) where T<:DependentDNA
    
    for item in self._dependentObjects
        for d in _Dependent_(asset)._graphParents
            if (d in _Dependent_(item)._graphChain) || d === item
                push!(_Dependent_(item)._graphChain,asset)
                break
            end
        end
    end
    
    push!(self._dependentObjects,asset)
    _Dependent_(asset)._graphID = length(self._dependentObjects) + ID_LOWER_BOUND

end

function fetch(self::DependentGraph,id::Integer)::DependentDNA
    return self._dependentObjects[id - ID_LOWER_BOUND]
end
