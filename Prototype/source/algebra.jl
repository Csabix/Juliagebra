# ? ---------------------------------
# ! €Algebra
# ? ---------------------------------

mutable struct Algebra
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

        new(renderer,rendererID,algebraDependents,Vector{€Algebra}(),callback)
    end

end

_Algebra_(self::€Algebra)::Algebra = error("Missing \"_Algebra_\" func for instance of €Algebra")

function enqueue!(self::€Algebra)
    enqueue!(_Algebra_(self)._renderer,self)
end