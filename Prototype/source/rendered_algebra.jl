# ? ---------------------------------
# ! RenderedAlgebraDNA
# ? ---------------------------------

# TODO: rename this to RenderedAlgebra, then Create an actual RenderedAlgebra struct (one which doesnt requiere a renderer).
# TODO: Algebra struct must have dispatch on callback.
# TODO: Algebra type must be solo Type.
# TODO: RenderedAlgebra type must intersection (Union{}) of QueLock and RenderedAlgebra.
# TODO: QueLockGroup should be created like T = Union{T,C}.


mutable struct RenderedAlgebra <:AlgebraDNA
    _algebra::Algebra
    _queueLock::QueueLock
    _renderer::RendererDNA
    _rendererID::Int

    function RenderedAlgebra(plan::PlanDNA,renderer::RendererDNA,)
        algebra = Algebra(plan)
        new(algebra,QueueLock(),renderer,0)
    end

end

_RenderedAlgebra_(self::RenderedAlgebraDNA)::RenderedAlgebra = error("Missing \"_RenderedAlgebra_\" func for instance of RenderedAlgebraDNA")
_Algebra_(self::RenderedAlgebraDNA)::Algebra     = _RenderedAlgebra_(self)._algebra
_QueueLock_(self::RenderedAlgebraDNA)::QueueLock = _RenderedAlgebra_(self)._queueLock