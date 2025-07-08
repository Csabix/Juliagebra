# ? ---------------------------------
# ! RenderedAlgebraDNA
# ? ---------------------------------

mutable struct RenderedAlgebra <:AlgebraDNA
    _algebra::Algebra
    _queueLock::QueueLock
    _renderer::RendererDNA
    _rendererID::Int

    function RenderedAlgebra(plan::RenderedPlanDNA)
        algebra = Algebra(plan)
        renderedPlan = _RenderedPlan_(plan)
        new(algebra,QueueLock(),renderedPlan._renderer,0)
    end

end

_RenderedAlgebra_(self::RenderedAlgebraDNA)::RenderedAlgebra = error("Missing \"_RenderedAlgebra_\" func for instance of RenderedAlgebraDNA")
_Algebra_(self::RenderedAlgebraDNA)::Algebra     = _RenderedAlgebra_(self)._algebra
_QueueLock_(self::RenderedAlgebraDNA)::QueueLock = _RenderedAlgebra_(self)._queueLock