# ? ---------------------------------
# ! RenderedDependentDNA
# ? ---------------------------------

mutable struct RenderedDependent <:DependentDNA
    _dependent::Dependent
    _queueLock::QueueLock
    _renderer::RendererDNA
    _rendererID::Int

    function RenderedDependent(plan::RenderedPlanDNA)
        dependent = Dependent(plan)
        renderedPlan = _RenderedPlan_(plan)
        new(dependent,QueueLock(),renderedPlan._renderer,0)
    end

end

_RenderedDependent_(self::RenderedDependentDNA)::RenderedDependent = error("Missing \"_RenderedDependent_\" func for instance of RenderedDependentDNA")
_Dependent_(self::RenderedDependentDNA)::Dependent     = _RenderedDependent_(self)._dependent
_QueueLock_(self::RenderedDependentDNA)::QueueLock = _RenderedDependent_(self)._queueLock