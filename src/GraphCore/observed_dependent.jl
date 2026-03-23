# ? ---------------------------------
# ! ObservedDNA
# ? ---------------------------------

mutable struct Observed <: DependentDNA
    _dependent::Dependent
    _observer::Union{ObserverDNA,Nothing}
    _observerID::Int
end

_Dependent_(self::ObservedDNA)::Dependent = return _Observed_(self)._dependent
_Observed_(self::ObservedDNA)::Observed = error("Missing func!")

getObserverID(self::ObservedDNA) = return _Observed_(self)._observerID
getObserver(self::ObservedDNA) = return _Observed_(self)._observer

function Observed(callback::Function,graphParents::Vector{<:DependentDNA})::Observed
    dependent = Dependent(callback,graphParents)
    observer = nothing
    observerID = 0
    return Observed(dependent,observer,observerID)
end

function Observed(plan::ObservedPlanDNA)::Observed
    dependent = Dependent(plan)
    observer = nothing
    observerID = 0
    return Observed(dependent,observer,observerID)
end

function evalGraph(self::ObservedDNA)
    afterNodeEval(self)
    evalChain(getChain(self))
    sync_all!()
end

function afterNodeEval(self::ObservedDNA)
    sync!(_Observed_(self)._observer,self)
end

function hasObserver(self::ObservedDNA)
    observed = _Observed_(self)
    id = observed._observerID
    return id != 0 && 
           _Observer_(observed._observer)._observedItems[id] === self
end

