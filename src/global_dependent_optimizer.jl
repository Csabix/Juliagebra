
# ? ---------------------------------
# ! GlobalDependentOptimizer
# ? ---------------------------------

@kwdef mutable struct GlobalDependentOptimizer
    _intersectionPrimitiveIters::Dict{Any,Any} = Dict{Any,Any}()
end

function getIntersectionPrimitiveIter!(self::GlobalDependentOptimizer,geometry::Any,T::Type{<:Primitive},call::Function)
    local gvh::GenericValueHolderDependent
    
    if (haskey(self._intersectionPrimitiveIters,geometry))
        gvh = self._intersectionPrimitiveIters[geometry]
    else
        gvh = GenericValueHolder(call,PrimitivesOf{T},[geometry])
        self._intersectionPrimitiveIters[geometry] = gvh
    end

    return gvh
end

function getIntersectionPrimitiveIter!(self::GlobalDependentOptimizer,geometry::Any,T::Type{<:AABBPrimitive})::LazyLBVHDependent{PrimitivesOf{T}}
    local llbvh::LazyLBVHDependent{PrimitivesOf{T}}
    
    if (haskey(self._intersectionPrimitiveIters,geometry))
        llbvh = self._intersectionPrimitiveIters[geometry]
    else
        llbvh = LazyLBVH(PrimitivesOf{T},geometry)
        self._intersectionPrimitiveIters[geometry] = llbvh
    end

    return llbvh
end