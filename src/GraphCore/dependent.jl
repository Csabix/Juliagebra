# ? ---------------------------------
# ! DependentDNA
# ? ---------------------------------

mutable struct Dependent
    _graphID::Int                       
    _graphParents::Vector{<:DependentDNA} # ? Who do I Depend on?
    _entryNodes::Vector{Any}
    _dependentChain::DependentChain # ? Who Depends on me (collectively)?
    _callback::Function
end

_Dependent_(self::DependentDNA)::Dependent = error("Missing \"_Dependent_\" for subclass of DependentDNA")

getGraphParents(self::DependentDNA) = return _Dependent_(self)._graphParents
getGraphParent(self::DependentDNA,idx::Int) = return getGraphParents(self)[idx]
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

function Dependent(callback::Function,graphParents::Vector{<:DependentDNA})
    dependentChain = DependentChain()
    entryNodes = Vector{Any}(undef,length(graphParents))
    
    self = Dependent(0,graphParents,entryNodes,dependentChain,callback)
    _setEntryNodes(self)

    return self
end

evalGraph(self::DependentDNA) = evalChain(getChain(self))
setEntryNodes(self::DependentDNA) = _setEntryNodes(_Dependent_(self))

beforeNodeEval(self::DependentDNA) = setEntryNodes(self)
onNodeEval(self::DependentDNA) = error("Missing \"onNodeEval\" for subclass of DependentDNA")
afterNodeEval(self::DependentDNA) = nothing

evalCallbackDpEntry(self::DependentDNA) = return self

"""
Eval the callback of a Dependent with every input node as type **evalCallbackDpEntry()**, 
then dispatch onto the result with **evalCallbackDpReturn()**

- The params given in a tuple to **callbackParams** will be entered into the user defined **_callback** starting from the first element.
- The params given in a tuple to **returnParams** will be entered into **evalCallbackDpReturn** after the returned value, starting from the first element.
"""
function evalCallbackDp(self::DependentDNA; callbackParams = (), returnParams = ()) 
    
    entryNodes = getEntryNodes(self)
    
    returnVal = getCallback(self)(callbackParams...,entryNodes...)
    evalCallbackDpReturn(self,returnVal,returnParams...)
end

evalCallbackDpReturn(self::DependentDNA,returnVal,returnParams...) = error("Missing \"evalCallbackDpReturn\" for subclass of $(typeof(self)) for $(typeof(returnVal))")
evalCallbackDpReturn(self::DependentDNA,::Nothing,returnParams...) = error("Missing \"evalCallbackDpReturn\" for subclass of DependentDNA (on Nothing)")