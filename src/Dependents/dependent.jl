# ? ---------------------------------
# ! DependentDNA
# ? ---------------------------------

mutable struct Dependent
    _graphID::Int                       
    _graphParents::Vector{DependentDNA}   
    _dependentChain::DependentChain
    _callback::Function
end

_Dependent_(self::DependentDNA)::Dependent = error("Missing \"_Dependent_\" for subclass of DependentDNA")

function Dependent(callback::Function,graphParents::Vector{DependentDNA})
    dependentChain = DependentChain()
    return Dependent(0,graphParents,dependentChain,callback)
end

function Dependent(plan::PlanDNA)
    
    graphParents = Vector{DependentDNA}()
    callback = _Plan_(plan)._callback

    for parent in _Plan_(plan)._graphParents
        push!(graphParents,_Plan_(parent)._dependent)
    end
    
    return Dependent(callback,graphParents)
end

getGraphParents(self::DependentDNA) = return _Dependent_(self)._graphParents
getGraphID(self::DependentDNA) = return _Dependent_(self)._graphID - ID_LOWER_BOUND
getChain(self::DependentDNA) = return _Dependent_(self)._dependentChain

evalCallback(self::DependentDNA,params...) = error("Missing \"evalCallback\" for subclass of DependentDNA")
dpCallbackReturn(self::DependentDNA,others...)    = error("Missing \"dispatchCallbackReturn\" for subclass of DependentDNA")
dpCallbackReturn(self::DependentDNA,::Nothing) = error("Missing \"dispatchCallbackReturn\" for subclass of DependentDNA (on Nothing)")
dpEvalCallback(self::DependentDNA,params...) = dpCallbackReturn(self,params...,evalCallback(self,params...))

onGraphAdd(parent::DependentDNA,child) = chain!(getChain(parent),child)
onGraphEval(self::DependentDNA) =  error("Missing \"onGraphEval\" for subclass of DependentDNA")
afterGraphEval(self::DependentDNA) = nothing

function evalGraph(self::DependentDNA)
    dependentChain = getChain(self)
    
    for item in dependentsOf(dependentChain)
        onGraphEval(item)
        afterGraphEval(item)
    end
    
    for item in observersOf(dependentChain)
        postGraphEval(item)
    end
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