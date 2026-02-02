
# ? ---------------------------------
# ! GlobalPlanOptimizer
# ? ---------------------------------

@kwdef mutable struct GlobalPlanOptimizer
    _intersectionPlans::Dict{PlanDNA,PlanDNA} = Dict{PlanDNA,PlanDNA}()
end

function getIntersectionPlan!(self::GlobalPlanOptimizer,geometry::PlanDNA,T::Type{<:Primitive},call::Function)
    local gvh::GenericValueHolderPlan
    
    if (haskey(self._intersectionPlans,geometry))
        gvh = intersectionPlans[geometry]
    else
        gvh = GenericValueHolder(call,PrimitivesOf{T},[geometry])
        intersectionPlans[geometry] = gvh
    end

    return gvh
end

function getIntersectionPlan!(self::GlobalPlanOptimizer,geometry::PlanDNA,T::Type{<:AABBPrimitive})
    local llbvh::LazyLBVHPlan
    
    if (haskey(self._intersectionPlans,geometry))
        llbvh = self._intersectionPlans[geometry]
    else
        llbvh = LazyLBVH(PrimitivesOf{T},geometry)
        self._intersectionPlans[geometry] = llbvh
    end

    return llbvh
end