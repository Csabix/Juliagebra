# ? ---------------------------------
# ! €Algebra
# ? ---------------------------------

mutable struct Algebra <:€QueueLock
    _queueLock::QueueLock
    
    _renderer::€Renderer
    _rendererID::Int

    _dependents::Vector{€Algebra}
    _graph::Vector{€Algebra}

    _callback::Function

    function Algebra(renderer::€Renderer,rendererID::Int,planDependents::Vector{€Plan},callback::Function)
        algebraDependents = Vector{€Algebra}()
        
        for plan in planDependents
            push!(algebraDependents,_Algebra_(plan))
        end

        new(QueueLock(),renderer,rendererID,algebraDependents,Vector{€Algebra}(),callback)
    end

end

_Algebra_(self::€Algebra)::Algebra = error("Missing \"_Algebra_\" func for instance of €Algebra")
_QueueLock_(self::€Algebra)::QueueLock = _Algebra_(self)._queueLock

function senqueue!(self::€Algebra)
    senqueue!(_Algebra_(self)._renderer,self)
end