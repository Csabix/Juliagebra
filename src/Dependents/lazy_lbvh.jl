
# ? ---------------------------------
# ! LazyLBVHDependent{T}
# ? ---------------------------------

# TODO: refine LBVHCache-s generic parameter.

mutable struct LazyLBVHDependent{T <: PrimitivesOf{<:AABBPrimitive}} <: DependentDNA
    _dependent::Dependent
    _iter::Union{T,Nothing}
    _lbvh::LBVHCache
    @atomic _isCacheOld::Bool
    _cacheLock::ReentrantLock

    # YELLOW Thread
    function LazyLBVHDependent{T}(geometry::DependentDNA) where {T <: PrimitivesOf{<:AABBPrimitive3D}}
        dependent = Dependent([geometry]) do geometry
            return PrimitivesOf(geometry)
        end
        
        iter = nothing
        lbvh = LBVHCache{3}()
        isCacheOld = false
        cacheLock = ReentrantLock()

        new{T}(dependent,iter,lbvh,isCacheOld,cacheLock)
    end
end

_Dependent_(self::LazyLBVHDependent)::Dependent = self._dependent

function getLBVH(self::LazyLBVHDependent)
    isOld::Bool = @atomic self._isCacheOld
    # ? Skip building, if it is old.
    if (isOld)
        # ? Compete for building.
        lock(self._cacheLock) do 
            isOld = @atomic self._isCacheOld
            # ? Multiple threads competed, am I the first one?
            if (isOld)
                BuildLBVH!(self._lbvh,map(GetAABB, self._iter),MORTON_CODE_TYPE)
                @atomic self._isCacheOld = false
            end
        end
    end
    
    return self._lbvh
end

# YELLOW Thread
# RED Thread
onNodeEval(self::LazyLBVHDependent) = evalCallbackDp(self)

function evalCallbackDpReturn(self::LazyLBVHDependent{T},iter::T) where T
    self._iter = iter
    @atomic self._isCacheOld = true
end

evalCallbackDpEntry(self::LazyLBVHDependent)::LazyLBVHDependent = return self

# ? ---------------------------------
# ! LazyLBVH(T)
# ? ---------------------------------

# YELLOW Thread
LazyLBVH(T::Type{<:PrimitivesOf{<:AABBPrimitive}},geometry::DependentDNA) =
Build!(LazyLBVHDependent{T}(geometry))