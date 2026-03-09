
# ? ---------------------------------
# ! ObserverPool
# ? ---------------------------------

@kwdef mutable struct ObserverPool{T<:ObserverDNA}
    # ? 0 or more Observed are observed, has all Observers in pool.
    _observers::Vector{T} = Vector{T}()
    # ? 1 or more Observed are observed, is subset of _observers.
    _active::Vector{Union{T,Nothing}} = Vector{Union{T,Nothing}}()
end

function Base.size(self::ObserverPool)::Tuple{Int,Int}
    all::Int = length(self._observers)
    active::Int = length(self._active)

    return (all,active)
end

function add!!(self::ObserverPool{T}, observer::U) where {T,U<:T} 
    push!(self._observers,observer)
    push!(self._active,nothing)
end

function activate!(self::ObserverPool,id::Int)
    self._active[id] = self._observers[id]
end

function Base.getindex(self::ObserverPool{T},idx::Int,::Val{:active}) where {T}
    return self._active[idx]
end

function Base.getindex(self::ObserverPool{T},idx::Int,::Val{:all}) where {T}
    return self._observers[idx]
end

function Base.length(self::ObserverPool)::Int
    return length(self._active)
end

function Base.iterate(self::ObserverPool, state = 1)
    # TODO: Continue this.
    if state > length(self)
        return nothing
    end

    return (self[state,Val(:active)],state+1)
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