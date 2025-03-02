mutable struct AlgebraLogic
    _shrd::SharedData
    _algebraObjects::Vector{AlgebraDNA}

    function AlgebraLogic(shrd::SharedData)
        new(shrd,Vector{AlgebraDNA}())
    end

end

function fuse!(self::AlgebraLogic,asset::T) where T<:AlgebraDNA
    for item in self._algebraObjects
        for d in _Algebra_(asset)._dependents
            if (d in _Algebra_(item)._graph) || d === item
                push!(_Algebra_(item)._graph,asset)
                break
            end
        end
    end
    push!(self._algebraObjects,asset)
    _Algebra_(asset)._algebraID = length(self._algebraObjects) + ID_LOWER_BOUND
end

function fetch(self::AlgebraLogic,id::Integer)::AlgebraDNA
    return self._algebraObjects[id - ID_LOWER_BOUND]
end

function init!(_loc::AlgebraLogic)

end

function update!(_loc::AlgebraLogic)

end

function destroy!(_loc::AlgebraLogic)

end
