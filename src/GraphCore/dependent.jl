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

getGraphParents(self::DependentDNA) = return _Dependent_(self)._graphParents
getGraphID(self::DependentDNA) = return _Dependent_(self)._graphID - ID_LOWER_BOUND
getChain(self::DependentDNA) = return _Dependent_(self)._dependentChain
getCallback(self::DependentDNA) = return _Dependent_(self)._callback

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

evalGraph(self::DependentDNA) = evalChain(getChain(self))

onNodeEval(self::DependentDNA) =  error("Missing \"onNodeEval\" for subclass of DependentDNA")
afterNodeEval(self::DependentDNA) = nothing

dpEvalCallback(self::DependentDNA,params...) = dpCallbackReturn(self,params...,evalCallback(self,params...))
evalCallback(self::DependentDNA,params...) = error("Missing \"evalCallback\" for subclass of DependentDNA")
dpCallbackReturn(self::DependentDNA,others...)    = error("Missing \"dispatchCallbackReturn\" for subclass of $(typeof(self)) for $(typeof(others...))")
dpCallbackReturn(self::DependentDNA,::Nothing) = error("Missing \"dispatchCallbackReturn\" for subclass of DependentDNA (on Nothing)")

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