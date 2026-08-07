
# ? ---------------------------------
# ! LazyLBVH{T}
# ? ---------------------------------

# TODO: refine LBVHCache-s generic parameter.

mutable struct LazyLBVH{T <: PrimitivesOf{<:AABBPrimitive}}
    _iter::Union{T,Nothing}
    _lbvh::LBVHCache
    @atomic _isCacheOld::Bool
    _cacheLock::ReentrantLock

    # YELLOW Thread
    function LazyLBVH{T}() where {T <: PrimitivesOf{<:AABBPrimitive3D}}
        iter = nothing
        lbvh = LBVHCache{3}()
        isCacheOld = false
        cacheLock = ReentrantLock()

        new{T}(iter,lbvh,isCacheOld,cacheLock)
    end
end

function getLBVH(self::LazyLBVH)
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

convert_callback_entry(self::LazyLBVH)::LazyLBVH = self

function convert_callback_result(element::LazyLBVH{T}, result) where T
    element._iter = result
    @atomic element._isCacheOld = true
    return element
end

function eval_node(::LazyLBVH{T}, callback::Function, arguments::Vector{Any})::Any where T
    return callback(arguments...)
end

# ? ---------------------------------
# ! LazyLBVH(T)
# ? ---------------------------------

function LazyLBVH(T::Type{<:PrimitivesOf{<:AABBPrimitive}},geometry::Any)
    return add_node!(LazyLBVH{T}(),[geometry]) do g
        return PrimitivesOf(g)
    end
end
