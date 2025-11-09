# ? ---------------------------------
# ! DependentChain
# ? ---------------------------------

@kwdef mutable struct DependentChain
    _vec::Vector{DependentDNA} = Vector{DependentDNA}()
    _set::Set{ObserverDNA} = Set{ObserverDNA}()
end

function enchain!(self::DependentChain,item::DependentDNA)
    push!(self._vec,item)
end

function enchain!(self::DependentChain,item::ObservedDNA)
    observer = _Observed_(item)._observer
    
    push!(self._vec,item)
    push!(self._set,observer)
end

dependentsOf(self::DependentChain) = return self._vec
observersOf(self::DependentChain) = return self._set

function evalChain(self::DependentChain)
    for item in dependentsOf(self)
        onGraphEval(item)
        afterGraphEval(item)
    end
    
    for item in observersOf(self)
        postGraphEval(item)
    end
end