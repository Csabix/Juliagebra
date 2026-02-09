
# ? ---------------------------------
# ! LazyLBVHPlan{T}
# ? ---------------------------------

mutable struct LazyLBVHPlan{T} <: PlanDNA
    _plan::Plan

    function LazyLBVHPlan{T}(plan::PlanDNA) where T
        plans = Vector{PlanDNA}([plan])
        
        callback = function (v)
            return PrimitivesOf(v)
        end

        plan = Plan(callback,plans)
        new(plan)
    end
end

_Plan_(self::LazyLBVHPlan)::Plan = return self._plan

# ? ---------------------------------
# ! LazyLBVHDependent{T}
# ? ---------------------------------

# TODO: Cache LBVH result with a shared Vector, insted of Tuple.
# TODO: Refine the, type of Union{Tuple,Nothing}.

mutable struct LazyLBVHDependent{T <: PrimitivesOf{<:AABBPrimitive}} <: DependentDNA
    _dependent::Dependent
    _iter::Union{T,Nothing}
    _lbvh::LBVHCache
    _isCacheOld::Bool

    function LazyLBVHDependent{T}(plan::LazyLBVHPlan{T}) where {T <: PrimitivesOf{<:AABBPrimitive3D}}
        dependent = Dependent(plan)
        iter = nothing
        lbvh = LBVHCache{3}()
        isCacheOld = false

        self = new{T}(dependent,iter,lbvh,isCacheOld)
        onNodeEval(self)

        return self
    end
end

_Dependent_(self::LazyLBVHDependent)::Dependent = self._dependent

function getLBVH(self::LazyLBVHDependent)
    
    # TODO: continue from here.
    # ! 1.932
    # ! 0.979
    # ! 17

    if (self._isCacheOld)
        BuildLBVH!(self._lbvh,map(GetAABB, self._iter),MORTON_CODE_TYPE)
        self._isCacheOld = false
    end
    
    return self._lbvh
end

onNodeEval(self::LazyLBVHDependent) = evalCallbackDp(self)

function evalCallbackDpReturn(self::LazyLBVHDependent{T},iter::T) where T
    self._iter = iter
    self._isCacheOld = true
end

evalCallbackDpEntry(self::LazyLBVHDependent)::LazyLBVHDependent = return self

function Plan2Dependent(plan::LazyLBVHPlan{T})::LazyLBVHDependent{T} where T
    return LazyLBVHDependent{T}(plan)
end

# ? ---------------------------------
# ! LazyLBVH(T)
# ? ---------------------------------

function _LazyLBVH(;
        _app::AppDNA = implicitApp,
        _geom::PlanDNA,
        _T::Type)

        plan = LazyLBVHPlan{_T}(_geom)
        submit!(_app,plan)
        return plan
end

LazyLBVH(T::Type{<:PrimitivesOf{<:AABBPrimitive}},geom::PlanDNA) =
_LazyLBVH(_geom = geom, _T = T)