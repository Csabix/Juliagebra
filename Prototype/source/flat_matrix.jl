
mutable struct FlatMatrix{LAYER,T}
    _manager::FlatMatrixManager{T}
    
    function FlatMatrix{LAYER,T}(manager::FlatMatrixManager{T}) where {LAYER,T}
        new(manager)
    end
end

function Base.getindex(self::FlatMatrix{LAYER,T},u,v)::T where {LAYER,T}
    return self._manager[LAYER,u,v]
end

function Base.setindex!(self::FlatMatrix{LAYER,T},item::T,u,v) where {LAYER,T}
    self._manager[LAYER,u,v] = item
end

Base.string(self::FlatMatrix{LAYER,T}) where {LAYER,T} = return string(self._manager,LAYER)

height(self::FlatMatrix{LAYER,T}) where {LAYER,T} = return height(self._manager,LAYER)
width(self::FlatMatrix{LAYER,T}) where {LAYER,T} = return width(self._manager,LAYER)

