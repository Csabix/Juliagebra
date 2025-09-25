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

function Observed(callback::Function,graphParents::Vector{DependentDNA})::Observed
    dependent = Dependent(callback,graphParents)
    observer = nothing
    observerID = 0
    return Observed(dependent,observer,observerID)
end

function Observed(plan::PlanDNA)::Observed
    dependent = Dependent(plan)
    observer = nothing
    observerID = 0
    return Observed(dependent,observer,observerID)
end

function add!!(collector::ObserverDNA,collected::ObservedDNA)
    observer = _Observer_(collector)
    observed = _Observed_(collected)

    push!(observer._observedItems,collected)
    
    observed._observer = collector
    observed._observerID = length(observer._observedItems)

    added!(collector,collected)
end

function afterGraphEval(self::ObservedDNA)
    sync!(_Observed_(self)._observer,self)
end

function hasObserver(self::ObservedDNA)
    observed = _Observed_(self)
    id = observed._observerID
    return id != 0 && 
           _Observer_(observed._observer)._observedItems[id] === self
end


