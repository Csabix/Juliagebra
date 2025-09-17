# ? ---------------------------------
# ! DependentChain
# ? ---------------------------------

@kwdef mutable struct DependentChain
    _vec::Vector{DependentDNA} = Vector{DependentDNA}()
    _set::Set{ObserverDNA} = Set{ObserverDNA}()
end

function chain!(self::DependentChain,item::DependentDNA)
    push!(self._vec,item)
end

function chain!(self::DependentChain,item::ObservedDNA)
    observer = _Observed_(item)._observer
    
    push!(self._vec,item)
    push!(self._set,observer)
end

function dependentsOf(self::DependentChain)
    return self._vec
end

function observersOf(self::DependentChain)
    return self._set
end