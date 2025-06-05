# ? ---------------------------------
# ! AlgebraDNA
# ? ---------------------------------

mutable struct Algebra
    _algebraID::Int
    _dependents::Vector{AlgebraDNA}
    _graph::Vector{AlgebraDNA}
    _callback::Function

    function Algebra(planDependents::Vector{PlanDNA},callback::Function)
        algebraDependents = Vector{AlgebraDNA}()
        
        for p in planDependents
            push!(algebraDependents,_Plan_(p)._algebra)
        end
        
        new(0,algebraDependents,Vector{AlgebraDNA}(),callback)
    end
end

_Algebra_(self::AlgebraDNA)::Algebra = error("Missing \"_Algebra_\" for subclass of AlgebraDNA")

evalCallback(self::AlgebraDNA,params...) = error("Missing \"evalCallback\" for subclass of AlgebraDNA")
dpCallbackReturn(self::AlgebraDNA,others...)    = error("Missing \"dispatchCallbackReturn\" for subclass of AlgebraDNA")
dpCallbackReturn(self::AlgebraDNA,undef::Undef) = error("Missing \"dispatchCallbackReturn\" for subclass of AlgebraDNA (on Undef)")
dpEvalCallback(self::AlgebraDNA,params...) = dpCallbackReturn(self,params...,evalCallback(self,params...))

onGraphEval(self::AlgebraDNA) =  error("Missing \"onGraphEval\" for subclass of AlgebraDNA")

function evalGraph(self::AlgebraDNA)
    for item in _Algebra_(self)._graph
        onGraphEval(item)
    end
end