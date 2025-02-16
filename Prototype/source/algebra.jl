# ? ---------------------------------
# ! AlgebraDNA
# ? ---------------------------------

mutable struct Algebra <:QueueLockDNA
    _queueLock::QueueLock
    
    _renderer::RendererDNA
    _rendererID::Int

    _dependents::Vector{AlgebraDNA}
    _graph::Vector{AlgebraDNA}

    _callback::Function

    function Algebra(renderer::RendererDNA,rendererID::Int,planDependents::Vector{PlanDNA},callback::Function)
        algebraDependents = Vector{AlgebraDNA}()
        
        for plan in planDependents
            push!(algebraDependents,_Algebra_(plan))
        end

        new(QueueLock(),renderer,rendererID,algebraDependents,Vector{AlgebraDNA}(),callback)
    end

end

_Algebra_(self::AlgebraDNA)::Algebra = error("Missing \"_Algebra_\" func for instance of AlgebraDNA")
_QueueLock_(self::AlgebraDNA)::QueueLock = _Algebra_(self)._queueLock

function senqueue!(self::AlgebraDNA)
    senqueue!(_Algebra_(self)._renderer,self)
end