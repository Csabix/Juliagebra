# ? ---------------------------------
# ! DependentDNA
# ? ---------------------------------

mutable struct Dependent
    _graphID::Int                       
    _graphParents::Vector{DependentDNA}
    _entryNodes::Vector{Any}
    _dependentChain::DependentChain
    _callback::Function
end

_Dependent_(self::DependentDNA)::Dependent = error("Missing \"_Dependent_\" for subclass of DependentDNA")

getGraphParents(self::DependentDNA) = return _Dependent_(self)._graphParents
getEntryNodes(self::DependentDNA) = return _Dependent_(self)._entryNodes
getGraphID(self::DependentDNA) = return _Dependent_(self)._graphID - ID_LOWER_BOUND
getChain(self::DependentDNA) = return _Dependent_(self)._dependentChain
getCallback(self::DependentDNA) = return _Dependent_(self)._callback

function _setEntryNodes(self::Dependent)
    entryNodes = self._entryNodes
    parents = self._graphParents

    for i in eachindex(parents)
        entryNodes[i] = evalCallbackDpEntry(parents[i])
    end
end

function Dependent(callback::Function,graphParents::Vector{DependentDNA})
    dependentChain = DependentChain()
    entryNodes = Vector{Any}(undef,length(graphParents))
    
    self = Dependent(0,graphParents,entryNodes,dependentChain,callback)
    _setEntryNodes(self)

    return self
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
setEntryNodes(self::DependentDNA) = _setEntryNodes(_Dependent_(self))

beforeNodeEval(self::DependentDNA) = setEntryNodes(self)
onNodeEval(self::DependentDNA) = error("Missing \"onNodeEval\" for subclass of DependentDNA")
afterNodeEval(self::DependentDNA) = nothing

evalCallbackDpEntry(self::DependentDNA) = return self

function evalCallbackDp(self::DependentDNA; callbackParams = (), returnParams = ()) 
    
    entryNodes = getEntryNodes(self)
    
    returnVal = getCallback(self)(callbackParams...,entryNodes...)
    evalCallbackDpReturn(self,returnVal,returnParams...)
end

evalCallbackDpReturn(self::DependentDNA,returnVal,returnParams...) = error("Missing \"evalCallbackDpReturn\" for subclass of $(typeof(self)) for $(typeof(returnVal))")
evalCallbackDpReturn(self::DependentDNA,::Nothing,returnParams...) = error("Missing \"evalCallbackDpReturn\" for subclass of DependentDNA (on Nothing)")

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