
mutable struct FlatMatrixManager{T}
    _data::Vector{T}
    _widths::Vector{Int}
    _heights::Vector{Int}
    _offsets::Vector{Int} # ! length(_offsets) + 1 == length(_heights) or length(_widths)

    function FlatMatrixManager{T}() where T
        new(Vector{T}(),
            Vector{Int}(),
            Vector{Int}(),
            [Int(0)])
    end
end

function initMatrix(self::FlatMatrixManager{T},width,height,initItem::T) where T
    push!(self._widths,width)
    push!(self._heights,height)
    for j in 1:height
        for i in 1:width
            push!(self._data,initItem)
        end
    end
    push!(self._offsets,width*height + self._offsets[end])
end

function fetchIndex(self::FlatMatrixManager,layer,u,v)
    offset = self._offsets[layer]
    width = self._widths[layer]
    return offset + u + (v-1) * width
end

function Base.getindex(self::FlatMatrixManager{T},layer,u,v)::T where T
    return self._data[fetchIndex(self,layer,u,v)]
end

function Base.setindex!(self::FlatMatrixManager{T},item::T,layer,u,v) where T
    self._data[fetchIndex(self,layer,u,v)] = item
end

function Base.string(self::FlatMatrixManager,layer)
    selfString = ""
    for v in 1:height(self,layer)
        for u in 1:width(self,layer)
            selfString *= "$(self[layer,u,v]) "
        end
        selfString *= "\n"
    end
    return selfString
end

function Base.string(self::FlatMatrixManager)
    selfString = ""
    for i in 1:layers(self)
        selfString *= string(self,i)
        selfString *= "\n"
    end
    return selfString[1:end-1]
end

Base.length(self::FlatMatrixManager) = return length(self._data)
layers(self::FlatMatrixManager) = return length(self._widths)
height(self::FlatMatrixManager,layer) = return self._heights[layer]
width(self::FlatMatrixManager,layer) = return self._widths[layer]
data(self::FlatMatrixManager) = return self._data

function triangulateInto!(self::Vector{T},mat::FlatMatrixManager,layer) where T
    # ! 1---3---5   u:->+ 
    # ! |##/|##/|      
    # ! |#/ |#/ |   v:|
    # ! |/  |/  |     V
    # ! 2---4---*     +
    for v in 1:(height(mat,layer)-1)
        for u in 1:(width(mat,layer)-1)
            push!(self,T(fetchIndex(mat,layer,u  ,v  )-1))
            push!(self,T(fetchIndex(mat,layer,u  ,v+1)-1))
            push!(self,T(fetchIndex(mat,layer,u+1,v  )-1))
        end
    end

    # ! *---3---4   u:->+ 
    # ! |  /|  /|      
    # ! | /#| /#|   v:|
    # ! |/##|/##|     V
    # ! 1---2---3     +
    for v in 2:(height(mat,layer))
        for u in 1:(width(mat,layer)-1)
            push!(self,T(fetchIndex(mat,layer,u  ,v  )-1))
            push!(self,T(fetchIndex(mat,layer,u+1,v  )-1))
            push!(self,T(fetchIndex(mat,layer,u+1,v-1)-1))
        end
    end
end
