# ? ---------------------------------
# ! DependentDNA
# ? ---------------------------------

mutable struct Dependent
    _graphID::Int                       
    _graphParents::Vector{DependentDNA}   
    _graphChain::Vector{DependentDNA}
    _callback::Function

    function Dependent(callback::Function,graphParents::Vector{DependentDNA})
        graphChain = Vector{DependentDNA}()
        new(0,graphParents,graphChain,callback)
    end
end

function Dependent(plan::PlanDNA)
    
    graphParents = Vector{DependentDNA}()
    callback = _Plan_(plan)._callback

    for parent in _Plan_(plan)._graphParents
        push!(graphParents,_Plan_(parent)._dependent)
    end
    
    return Dependent(callback,graphParents)
end

onGraphAdd(parent::DependentDNA,child::DependentDNA) = Dependent_onGraphAdd(parent,child)

function Dependent_onGraphAdd(parent::DependentDNA,child::DependentDNA)
    parentChain = _Dependent_(parent)._graphChain
    push!(parentChain,child)
end

_Dependent_(self::DependentDNA)::Dependent = error("Missing \"_Dependent_\" for subclass of DependentDNA")

getGraphParents(self::DependentDNA) = return _Dependent_(self)._graphParents
getGraphID(self::DependentDNA) = return _Dependent_(self)._graphID - ID_LOWER_BOUND

evalCallback(self::DependentDNA,params...) = error("Missing \"evalCallback\" for subclass of DependentDNA")
dpCallbackReturn(self::DependentDNA,others...)    = error("Missing \"dispatchCallbackReturn\" for subclass of DependentDNA")
dpCallbackReturn(self::DependentDNA,::Nothing) = error("Missing \"dispatchCallbackReturn\" for subclass of DependentDNA (on Nothing)")
dpEvalCallback(self::DependentDNA,params...) = dpCallbackReturn(self,params...,evalCallback(self,params...))

onGraphEval(self::DependentDNA) =  error("Missing \"onGraphEval\" for subclass of DependentDNA")
postGraphEval(self::DependentDNA) = nothing
afterGraphEval(self::DependentDNA) = nothing

function evalGraph(self::DependentDNA)
    for item in _Dependent_(self)._graphChain
        onGraphEval(item)
        afterGraphEval(item)
    end
    postGraphEval(self)
end

function to_string(self::DependentDNA)
    outStr = ""

    outStr *= "$(getGraphID(self))"
    outStr *= "\t: ["
    for parent in getGraphParents(self)
        outStr *= "$(getGraphID(parent)), "
    end
    outStr = outStr[1:end-2]
    outStr *= "]"

    return outStr
end