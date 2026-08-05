
# ? ---------------------------------
# ! GlobalNodeOptimizer
# ? ---------------------------------

@kwdef mutable struct GlobalNodeOptimizer
    _intersectionPrimitiveIters::Dict{Any,Any} = Dict{Any,Any}()
end

function getIntersectionPrimitiveIter!(self::GlobalNodeOptimizer,geometry::Any,::Type{<:Primitive},call::Function)
    local gvh::NodeHandle
    
    if (haskey(self._intersectionPrimitiveIters,geometry) && !isa(get_element(self._intersectionPrimitiveIters[geometry]), LazyLBVH))
        gvh = self._intersectionPrimitiveIters[geometry]
    else
        gvh = add_node!(call,PrimitivesOf(get_element(geometry)),[geometry])
        self._intersectionPrimitiveIters[geometry] = gvh
    end

    return gvh
end

function getIntersectionPrimitiveIter!(self::GlobalNodeOptimizer,geometry::Any,T::Type{<:AABBPrimitive})::NodeHandle
    local llbvh::NodeHandle
    
    if (haskey(self._intersectionPrimitiveIters,geometry) && isa(get_element(self._intersectionPrimitiveIters[geometry]), LazyLBVH))
        llbvh = self._intersectionPrimitiveIters[geometry]
    else
        llbvh = LazyLBVH(PrimitivesOf{T},geometry)
        self._intersectionPrimitiveIters[geometry] = llbvh
    end

    return llbvh
end