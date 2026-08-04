
# ? ---------------------------------
# ! LazyLBVHDependent{T}
# ? ---------------------------------

# TODO: refine LBVHCache-s generic parameter.

mutable struct LazyLBVHDependent{T <: PrimitivesOf{<:AABBPrimitive}}
    _iter::Union{T,Nothing}
    _lbvh::LBVHCache
    @atomic _isCacheOld::Bool
    _cacheLock::ReentrantLock

    _geometry::NodeHandle

    # YELLOW Thread
    function LazyLBVHDependent{T}(geometry::Any) where {T <: PrimitivesOf{<:AABBPrimitive3D}}
        iter = nothing
        lbvh = LBVHCache{3}()
        isCacheOld = false
        cacheLock = ReentrantLock()

        new{T}(iter,lbvh,isCacheOld,cacheLock,geometry)
    end
end

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
# onNodeEval(self::LazyLBVHDependent) = evalCallbackDp(self)
# function eval_node(element::LazyLBVHDependent,iter::T)::Any where T
#     println("--- EVAL LazyLBVHDependent ---")
#     return element
# end
function eval_node(element::LazyLBVHDependent{T}, callback::Function, arguments::Vector{Any})::Any where T
    # println("!!! EVAL LazyLBVHDependent !!!")
    return element
end

# function evalCallbackDpReturn(self::LazyLBVHDependent{T},iter::T) where T
#     println("--- EVAL LazyLBVHDependent ---")
#     self._iter = iter
#     @atomic self._isCacheOld = true
# end
function convert_callback_result(element::LazyLBVHDependent{T}, result) where T
    # println("!!! convert_callback_result !!!")
    return element
end

# evalCallbackDpEntry(self::LazyLBVHDependent)::LazyLBVHDependent = return self
function convert_callback_entry(self::LazyLBVHDependent)::LazyLBVHDependent
    # println("!!! convert_callback_entry !!!")
    # self._iter = iter
    # @atomic self._isCacheOld = true
    return self
end

# ? ---------------------------------
# ! LazyLBVH(T)
# ? ---------------------------------

# YELLOW Thread
# LazyLBVH(T::Type{<:PrimitivesOf{<:AABBPrimitive}},geometry::Any) =
# Build!(LazyLBVHDependent{T}(geometry))
function LazyLBVH(T::Type{<:PrimitivesOf{<:AABBPrimitive}},geometry::Any)
    add_node!(LazyLBVHDependent{T}(geometry),[geometry])
end
