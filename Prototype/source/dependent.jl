# ? ---------------------------------
# ! DependentDNA
# ? ---------------------------------

mutable struct Dependent
    _graphID::Int                       
    _graphParents::Vector{DependentDNA}   
    _graphChain::Vector{DependentDNA}
    _callback::Function

    function Dependent(plan::PlanDNA)
        
        graphParents = Vector{DependentDNA}()
        graphChain = Vector{DependentDNA}()
        callback = _Plan_(plan)._callback

        for parent in _Plan_(plan)._graphParents
            push!(graphParents,_Plan_(parent)._dependent)
        end
        
        new(0,graphParents,graphChain,callback)
    end
end

_Dependent_(self::DependentDNA)::Dependent = error("Missing \"_Dependent_\" for subclass of DependentDNA")

evalCallback(self::DependentDNA,params...) = error("Missing \"evalCallback\" for subclass of DependentDNA")
dpCallbackReturn(self::DependentDNA,others...)    = error("Missing \"dispatchCallbackReturn\" for subclass of DependentDNA")
dpCallbackReturn(self::DependentDNA,::Nothing) = error("Missing \"dispatchCallbackReturn\" for subclass of DependentDNA (on Nothing)")
dpEvalCallback(self::DependentDNA,params...) = dpCallbackReturn(self,params...,evalCallback(self,params...))

onGraphEval(self::DependentDNA) =  error("Missing \"onGraphEval\" for subclass of DependentDNA")

function evalGraph(self::DependentDNA)
    for item in _Dependent_(self)._graphChain
        onGraphEval(item)
    end
end