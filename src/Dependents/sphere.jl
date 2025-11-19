# ? ---------------------------------
# ! SpherePlan
# ? ---------------------------------


mutable struct SpherePlan <: RenderedPlanDNA
    _plan::RenderedPlan
end

function SpherePlan(callback::Function,plans::Vector{T}) where {T<:PlanDNA}
    plan = RenderedPlan(callback,plans)

    return SpherePlan(plan)
end

_RenderedPlan_(self::SpherePlan)::RenderedPlan = return self._plan

# ? ---------------------------------
# ! SphereDependent
# ? ---------------------------------

mutable struct SphereDependent <: RenderedDependentDNA
    _dependent::RenderedDependent
end

function SphereDependent(plan::SpherePlan)
    dependent = RenderedDependent(plan)

    return SphereDependent(dependent)
end

_RenderedDependent_(self::SphereDependent)::RenderedDependent = return self._dependent

Plan2Dependent(plan::SpherePlan)::SphereDependent = return SphereDependent(plan)

onGraphEval(self::SphereDependent) = return nothing

# ? ---------------------------------
# ! SphereRenderer
# ? ---------------------------------

mutable struct SphereRenderer <: RendererDNA{SphereDependent}
    _renderer::Renderer{SphereDependent}
end

function SphereRenderer(context::OpenGLData)
    renderer = Renderer{SphereDependent}(context)

    return SphereRenderer(renderer)
end

_Renderer_(self::SphereRenderer)::Renderer = return self._renderer

setRenderedID!(self::SphereRenderer,_,_) = return nothing

function added!(self::SphereRenderer,sphere::SphereDependent)
    
end

function addedAll!(self::SphereRenderer)

end

function sync!(self::SphereRenderer,sphere::SphereDependent)
    
end

function syncAll!(self::SphereRenderer)

end

function draw!(self::SphereRenderer,vp,selectedID,pickedID,cam,shrd)

end

function destroy!(self::SphereRenderer)
    
end

Plan2Observer(builder::OpenGLData, _::SpherePlan) = SingleRendererTactic(builder,SphereRenderer)

