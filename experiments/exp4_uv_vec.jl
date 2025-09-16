function at(self,u,v,last,width)
    return self[last + u + (v-1) * width]
end

mutable struct FlatMatrixManager{T}
    _data::Vector{T}
    _widths::Vector{Int}
    _heights::Vector{Int}
    _offsets::Vector{Int} # ! length(_offsets) + 1 == length(_heights) or length(_widths)
    _segmentItem::T

    function FlatMatrixManager{T}(segmentItem::T) where T
        new(Vector{T}(),
            Vector{Int}(),
            Vector{Int}(),
            [Int(0)],
            segmentItem)
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
    push!(self._data,self._segmentItem)
    push!(self._offsets,width*height + self._offsets[end] + 1)
end

function fetchIndex(self::FlatMatrixManager,matNum,u,v)
    offset = self._offsets[matNum]
    width = self._widths[matNum]
    return offset + u + (v-1) * width
end

function Base.getindex(self::FlatMatrixManager{T},matNum,u,v)::T where T
    return self._data[fetchIndex(self,matNum,u,v)]
end

function Base.setindex!(self::FlatMatrixManager{T},item::T,matNum,u,v) where T
    self._data[fetchIndex(self,matNum,u,v)] = item
end

function Base.string(self::FlatMatrixManager)
    selfString = ""
    for i in 1:length(self._widths)
        for v in 1:self._heights[i]
            for u in 1:self._widths[i]
                selfString *= "$(self[i,u,v]) "
            end
            selfString *= "\n"
        end
        selfString *= "$(self._data[fetchIndex(self,i,self._widths[i],self._heights[i])+1])"
        selfString *= "\n"
    end
    return selfString
end

Base.size(self::FlatMatrixManager) = return (length(self._widths),length(self._data))
height(self::FlatMatrixManager,matNum) = return self._heights[matNum]
width(self::FlatMatrixManager,matNum) = return self._widths[matNum]

mat = FlatMatrixManager{Int}(0)

initMatrix(mat,4,3,1)
initMatrix(mat,3,2,2)
initMatrix(mat,5,2,3)
initMatrix(mat,2,1,4)
initMatrix(mat,3,1,5)
initMatrix(mat,3,3,6)

println("$(mat)")

counter = 1

for i in 1:(size(mat)[1])
    for v in 1:height(mat,i)
        for u in 1:width(mat,i)
            mat[i,u,v] = counter
            global counter += 1
        end
    end
end

println("$(mat)")

#a = [1,1,1,1,
#     2,2,2,2,
#     3,3,3,3,
#     
#     4,4,4,
#     5,5,5,
#     
#     6,6,6,6,6,
#     7,7,7,7,7,
#     
#     8,8,
#     
#     9,9,9,
#     
#     66,66,66,
#     77,77,77,
#     88,88,88]
#
#w1 = 4
#h1 = 3
#s1 = w1*h1     
#
#w2 = 3
#h2 = 2
#s2 = w2*h2
#
#w3 = 5
#h3 = 2
#s3 = w3*h3
#
#w4 = 2
#h4 = 1
#s4 = w4*h4
#
#w5 = 3
#h5 = 1
#s5 = w5*h5
#
#w6 = 3
#h6 = 3
#s6 = w6*h6
#
#function iterateVec(self,last,width,height)
#    println("$(last) - $(width) - $(height)")
#    for v in 1:height
#        for u in 1:width
#            println("u:($(u)), v:($(v)) = $(at(self,u,v,last,width))")
#        end
#    end
#    println()
#end
#
#println(a)
#println()
#iterateVec(a,0,w1,h1)
#iterateVec(a,s1,w2,h2)
#iterateVec(a,s1+s2,w3,h3)
#iterateVec(a,s1+s2+s3,w4,h4)
#iterateVec(a,s1+s2+s3+s4,w5,h5)
#iterateVec(a,s1+s2+s3+s4+s5,w6,h6)


