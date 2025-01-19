mutable struct AlgebraLogic
    _shrd::SharedData
    _algebraObjects::Vector{AlgebraObject}

    function AlgebraLogic(shrd::SharedData)
        new(shrd,Vector{AlgebraObject}())
    end

end

function fuse!(self::AlgebraLogic,asset::T) where T<:AlgebraObject
    push!(self._algebraObjects,asset)
end

function init!(_loc::AlgebraLogic)

end

function update!(_loc::AlgebraLogic)

end

function destroy!(_loc::AlgebraLogic)

end
