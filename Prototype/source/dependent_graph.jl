mutable struct DependentGraph
    _shrd::SharedData
    _algebraObjects::Vector{AlgebraDNA}

    function DependentGraph(shrd::SharedData)
        new(shrd,Vector{AlgebraDNA}())
    end

end

# TODO: idotol valo fugges, timestep alapu osszefesulessel

function add!!(self::DependentGraph,asset::T) where T<:AlgebraDNA
    
    for item in self._algebraObjects
        for d in _Algebra_(asset)._graphParents
            if (d in _Algebra_(item)._graphChain) || d === item
                push!(_Algebra_(item)._graphChain,asset)
                break
            end
        end
    end
    
    push!(self._algebraObjects,asset)
    _Algebra_(asset)._graphID = length(self._algebraObjects) + ID_LOWER_BOUND

end

function fetch(self::DependentGraph,id::Integer)::AlgebraDNA
    return self._algebraObjects[id - ID_LOWER_BOUND]
end
