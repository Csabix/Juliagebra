
# ? ---------------------------------
# ! Dependent
# ? ---------------------------------

"""
Nodes in the Graph are represented by this struct.
- Construction pipeline takes it through Builder -> Adder.
"""
mutable struct Dependent
    _graphID::Int                       
    _graphParents::Vector{<:DependentDNA} # ? Who do I Depend on?
    _entryNodes::Vector{Any}
    _subgraph::InsertionTopoSubgraph # ? Who Depends on me (collectively)?
    _callback::Function

    # ? Was this node evaled by an EvalWorker?
    _evaledcond::CompletedCondition

    function Dependent(callback::Function,graphParents::Vector{<:DependentDNA})
        schedule = InsertionTopoSubgraph()
        
        _graphParents = copy(graphParents)
        @assert allunique(_graphParents) "Dependent parents have duplicates!"

        entryNodes = Vector{Any}(undef,length(_graphParents))
        evaledcond::CompletedCondition = CompletedCondition()

        new(0,_graphParents,entryNodes,schedule,callback,evaledcond)
    end
end

Base.show(::Any, ::Any, ::DependentDNA) = return nothing

_Dependent_(self::DependentDNA)::Dependent = error("Missing \"_Dependent_\" for subclass of DependentDNA")

getGraphParents(self::DependentDNA) = return _Dependent_(self)._graphParents
getGraphParent(self::DependentDNA,idx::Int) = return getGraphParents(self)[idx]
getEntryNodes(self::DependentDNA) = return _Dependent_(self)._entryNodes
getGraphID(self::DependentDNA) = return _Dependent_(self)._graphID
get_subgraph(self::DependentDNA) = return _Dependent_(self)._subgraph
getCallback(self::DependentDNA) = return _Dependent_(self)._callback
get_evaledcond(self::DependentDNA)::CompletedCondition = return _Dependent_(self)._evaledcond

_isUnbuilt(self::Dependent)::Bool = return (self._graphID == 0)
isUnbuilt(self::DependentDNA)::Bool = return _isUnbuilt(_Dependent_(self))

function setEntryNodes(self::DependentDNA)
    d::Dependent = _Dependent_(self)
    entryNodes = d._entryNodes
    parents = d._graphParents

    for i in eachindex(parents)
        entryNodes[i] = evalCallbackDpEntry(parents[i])
    end
end

function beforeNodeEval(self::DependentDNA)
    setEntryNodes(self)
    if !isempty(implicitApp._pending_tessellations) && any(is_pending_tessellation, getGraphParents(self))
        _resolve_pending_tessellations!()
    end
end
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

"""
Model will use this function, to set the node to have a starting state.
- This function can be overridden if neccessary.
- Function must take into parent states as well.
- Will always run on App thread.
"""
function node_start!(self::DependentDNA)
    beforeNodeEval(self)
    onNodeEval(self)
    afterNodeEval(self)
end

"""
Model will use this function, to update the node's state regarding the updated parents.
- This function can be overridden if neccessary.
- Runs on worker specified by thread_affinity function. 
"""
function node_eval!(self::DependentDNA)
    beforeNodeEval(self)
    onNodeEval(self)
    afterNodeEval(self)
end



