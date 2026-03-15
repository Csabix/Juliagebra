
# ? ---------------------------------
# ! ObserverPool
# ? ---------------------------------

@kwdef mutable struct ObserverPool{T<:ObserverDNA}
    _observers::Vector{T} = Vector{T}()
    _active::Vector{Bool} = Vector{Bool}()
end

function add!!(self::ObserverPool{T}, observer::U) where {T,U<:T}  
    push!(self._observers,observer)
    push!(self._active,false)
end

activate!(self::ObserverPool,id::Int) = self._active[id] = true
Base.length(self::ObserverPool)::Int = return length(self._observers)

function Base.getindex(self::ObserverPool{T},idx::Int)::T where {T}
    return self._observers[idx]
end

function Base.iterate(self::ObserverPool, state = 1)
    all = length(self._observers)
    
    for i in state:all
        if self._active[i]
            return (self._observers[i],i+1)
        end
    end

    return nothing
end

# ? After empty!, a pool can be reused.
# ? Note that all observers are destroyed.
function Base.empty!(self::ObserverPool)
    for observer in self._observers
        destroy!(observer)
    end

    empty!(self._active)
    empty!(self._observer)
end

function Base.fill!(self::ObserverPool{T},observers::Vector{<:T}) where {T}
    for observer in observers
        add!!(self,observer)
    end
end