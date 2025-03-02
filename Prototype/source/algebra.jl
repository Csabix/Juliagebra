# ? ---------------------------------
# ! AlgebraDNA
# ? ---------------------------------

mutable struct Algebra <:QueueLockDNA
    _queueLock::QueueLock
    
    _renderer::RendererDNA
    _algebraID::Int

    _dependents::Vector{AlgebraDNA}
    _graph::Vector{AlgebraDNA}

    _callback::Function

    function Algebra(renderer::RendererDNA,planDependents::Vector{PlanDNA},callback::Function)
        algebraDependents = Vector{AlgebraDNA}()
        
        for p in planDependents
            push!(algebraDependents,_Plan_(p)._algebra)
        end

        new(QueueLock(),renderer,0,algebraDependents,Vector{AlgebraDNA}(),callback)
    end

end

_Algebra_(self::AlgebraDNA)::Algebra = error("Missing \"_Algebra_\" func for instance of AlgebraDNA")
_QueueLock_(self::AlgebraDNA)::QueueLock = _Algebra_(self)._queueLock