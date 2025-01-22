mutable struct AlgebraLogic
    _shrd::SharedData
    _algebraObjects::Vector{Algebras}

    function AlgebraLogic(shrd::SharedData)
        new(shrd,Vector{Algebras}())
    end

end

function fuse!(self::AlgebraLogic,asset::T) where T<:Algebras
    for item in self._algebraObjects
        for d in super(asset)._dependents
            if (d in super(item)._graph) || d === item
                push!(super(item)._graph,asset)
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
