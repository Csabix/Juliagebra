
# ? ---------------------------------
# ! LazyLBVHDependent{T}
# ? ---------------------------------

# TODO: refine LBVHCache-s generic parameter.

mutable struct LazyLBVHDependent{T <: PrimitivesOf{<:AABBPrimitive}} <: DependentDNA
    _dependent::Dependent
    _iter::Union{T,Nothing}
    _lbvh::LBVHCache
    _isCacheOld::Bool

    # YELLOW Thread
    function LazyLBVHDependent{T}(geometry::DependentDNA) where {T <: PrimitivesOf{<:AABBPrimitive3D}}
        dependent = Dependent([geometry]) do geometry
            return PrimitivesOf(geometry)
        end
        
        iter = nothing
        lbvh = LBVHCache{3}()
        isCacheOld = false

        new{T}(dependent,iter,lbvh,isCacheOld)
    end
end

_Dependent_(self::LazyLBVHDependent)::Dependent = self._dependent

function getLBVH(self::LazyLBVHDependent)
    if (self._isCacheOld)
        BuildLBVH!(self._lbvh,map(GetAABB, self._iter),MORTON_CODE_TYPE)
        self._isCacheOld = false
    end
    
    return self._lbvh
end

# YELLOW Thread
# RED Thread
onNodeEval(self::LazyLBVHDependent) = evalCallbackDp(self)

function evalCallbackDpReturn(self::LazyLBVHDependent{T},iter::T) where T
    self._iter = iter
    self._isCacheOld = true
end

evalCallbackDpEntry(self::LazyLBVHDependent)::LazyLBVHDependent = return self

# ? ---------------------------------
# ! LazyLBVH(T)
# ? ---------------------------------

# YELLOW Thread
LazyLBVH(T::Type{<:PrimitivesOf{<:AABBPrimitive}},geometry::DependentDNA) =
Build!(LazyLBVHDependent{T}(geometry))