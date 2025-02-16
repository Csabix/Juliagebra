mutable struct AlgebraLogic
    _shrd::SharedData
    _algebraObjects::Vector{€Algebra}

    function AlgebraLogic(shrd::SharedData)
        new(shrd,Vector{€Algebra}())
    end

end

function fuse!(self::AlgebraLogic,asset::T) where T<:€Algebra
    for item in self._algebraObjects
        for d in _Algebra_(asset)._dependents
            if (d in _Algebra_(item)._graph) || d === item
                push!(_Algebra_(item)._graph,asset)
                break
            end
        end
    end
    push!(self._algebraObjects,asset)
end

function init!(_loc::AlgebraLogic)

end

function update!(_loc::AlgebraLogic)

end

function destroy!(_loc::AlgebraLogic)

end
