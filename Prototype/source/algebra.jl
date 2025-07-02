# ? ---------------------------------
# ! AlgebraDNA
# ? ---------------------------------

mutable struct Algebra
    _graphID::Int                       # ? was algebraID
    _graphParents::Vector{AlgebraDNA}   # ? was dependents
    _graphChain::Vector{AlgebraDNA}     # ? was graph
    _callback::Function

    function Algebra(plan::PlanDNA)
        
        graphParents = Vector{AlgebraDNA}()
        graphChain = Vector{AlgebraDNA}()
        callback = _Plan_(plan)._callback

        for parent in _Plan_(plan)._graphParents
            push!(graphParents,_Plan_(parent)._algebra)
        end
        
        new(0,graphParents,graphChain,callback)
    end
end

_Algebra_(self::AlgebraDNA)::Algebra = error("Missing \"_Algebra_\" for subclass of AlgebraDNA")

evalCallback(self::AlgebraDNA,params...) = error("Missing \"evalCallback\" for subclass of AlgebraDNA")
dpCallbackReturn(self::AlgebraDNA,others...)    = error("Missing \"dispatchCallbackReturn\" for subclass of AlgebraDNA")
dpCallbackReturn(self::AlgebraDNA,undef::Undef) = error("Missing \"dispatchCallbackReturn\" for subclass of AlgebraDNA (on Undef)")
dpEvalCallback(self::AlgebraDNA,params...) = dpCallbackReturn(self,params...,evalCallback(self,params...))

onGraphEval(self::AlgebraDNA) =  error("Missing \"onGraphEval\" for subclass of AlgebraDNA")

function evalGraph(self::AlgebraDNA)
    for item in _Algebra_(self)._graphChain
        onGraphEval(item)
    end
end