
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
# ! LazyLBVH{T}
# ? ---------------------------------

# TODO: Cache LBVH result with a shared Vector, insted of Tuple.
# TODO: Refine the, type of Union{Tuple,Nothing}.

mutable struct LazyLBVH{T <: PrimitivesOf{<:AABBPrimitive}} <: DependentDNA
    _dependent::Dependent
    _iter::Union{T,Nothing}
    _lbvh::Union{Tuple,Nothing}

    function LazyLBVH{T}(plan::LazyLBVHPlan{T}) where T
        dependent = Dependent(plan)
        self = new{T}(dependent,nothing,nothing)
        onNodeEval(self)
        return self
    end
end

_Dependent_(self::LazyLBVH)::Dependent = self._dependent

onNodeEval(self::LazyLBVH) = evalCallbackDp(self)

function evalCallbackDpReturn(self::LazyLBVH{T},iter::T) where T
    self._iter = iter
    self._lbvh = nothing
end

evalCallbackDpEntry(self::LazyLBVH)::LazyLBVH = return self

function getLBVH(self::LazyLBVH)::Tuple
    if (isnothing(self._lbvh))
        self._lbvh = BuildLBVH(map(GetAABB, self._iter), MORTON_CODE_TYPE)
    end
    
    return self._lbvh
end