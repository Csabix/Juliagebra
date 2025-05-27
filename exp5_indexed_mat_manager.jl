
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

function triangulateInto!(self::Vector{T},mat::FlatMatrixManager,layer) where T
    # ! 1---3---5   u:->+ 
    # ! |##/|##/|      
    # ! |#/ |#/ |   v:|
    # ! |/  |/  |     V
    # ! 2---4---*     +
    for v in 1:(height(mat,layer)-1)
        for u in 1:(width(mat,layer)-1)
            push!(self,T(fetchIndex(mat,layer,u  ,v  )))
            push!(self,T(fetchIndex(mat,layer,u  ,v+1)))
            push!(self,T(fetchIndex(mat,layer,u+1,v  )))
        end
    end

    # ! *---3---4   u:->+ 
    # ! |  /|  /|      
    # ! | /#| /#|   v:|
    # ! |/##|/##|     V
    # ! 1---2---3     +
    for v in 2:(height(mat,layer))
        for u in 1:(width(mat,layer)-1)
            push!(self,T(fetchIndex(mat,layer,u  ,v  )))
            push!(self,T(fetchIndex(mat,layer,u+1,v  )))
            push!(self,T(fetchIndex(mat,layer,u+1,v-1)))
        end
    end
end

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

manager = FlatMatrixManager{Int}()

initMatrix(manager,4,3,1)
initMatrix(manager,3,2,2)
initMatrix(manager,5,2,3)
initMatrix(manager,2,1,4)
initMatrix(manager,3,1,5)
initMatrix(manager,3,3,6)

println("length - $(length(manager))")
println("$(manager)")

counter = 1

for i in 1:layers(manager)
    for v in 1:height(manager,i)
        for u in 1:width(manager,i)
            manager[i,u,v] = counter
            global counter += 1
        end
    end
end

println("length - $(length(manager))")
println("$(manager)")

indexes = Vector{Int}()
triangulateInto!(indexes,manager,6)
println("$(indexes)")

triangulateInto!(indexes,manager,3)
println("$(indexes)")

mat = FlatMatrix{6,Int}(manager)

counter = 50

for v in 1:height(mat)
    for u in 1:width(mat)
        mat[u,v] = counter
        global counter += 1
    end
end

println("mat:")
println("$(mat)")

println("manager:")
println("$(manager)")