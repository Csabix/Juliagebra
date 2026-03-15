
mutable struct FlatMatrix{T}
    _data::Vector{T}
    _width::Int
    _height::Int

    function FlatMatrix{T}(width::Int,height::Int) where T
        data = Vector{T}(undef,width*height)
        new(data,width,height)
    end
end

function fetchIndex(self::FlatMatrix,u,v)
    return u + (v-1) * self._width
end

function Base.getindex(self::FlatMatrix{T},u,v)::T where T
    return self._data[fetchIndex(self,u,v)]
end

function Base.setindex!(self::FlatMatrix{T},item::T,u,v) where T
    self._data[fetchIndex(self,u,v)] = item
end

height(self::FlatMatrix) = return self._height
width(self::FlatMatrix)= return self._width

struct TrianglesOf
    _vertexes::FlatMatrix
end

function Base.iterate(self::TrianglesOf,uvs = (1,1,1))
    u,v,s = uvs
    
    if (s==1)
        # ! 1---3---5   u:->+ 
        # ! |##/|##/|      
        # ! |#/ |#/ |   v:|
        # ! |/  |/  |     V
        # ! 2---4---*     +
        
        a = self._vertexes[u  ,v  ]
        b = self._vertexes[u  ,v+1]
        c = self._vertexes[u+1,v  ]
        abc = PTriangle(a,b,c)

        if (u==width(self._vertexes)-1)
            if (v==height(self._vertexes)-1)
                u = 1
                v = 2
                s = 2
            else
                v += 1
                u = 1
            end
        else
            u += 1
        end
        
        return (abc,(u,v,s))
    elseif (s==2)
        # ! *---3---4   u:->+ 
        # ! |  /|  /|      
        # ! | /#| /#|   v:|
        # ! |/##|/##|     V
        # ! 1---2---3     +
        
        a = self._vertexes[u  ,v  ]
        b = self._vertexes[u+1,v  ]
        c = self._vertexes[u+1,v-1]
        abc = PTriangle(a,b,c)

        if (u==width(self._vertexes)-1)
            if (v==height(self._vertexes))
                u = 0
                v = 0
                s = 3
            else
                v += 1
                u = 1
            end
        else
            u += 1
        end

        return (abc,(u,v,s))
    end
    
    return nothing
end

Base.length(self::TrianglesOf) = 2 * (width(self._vertexes) - 1) * (height(self._vertexes) - 1)

function Base.getindex(self::TrianglesOf, index::UInt)::Union{Nothing, PTriangle}
    w = width(self._vertexes) - 1
    h = height(self._vertexes) - 1
    number_of_quads = w * h

    if (index <= number_of_quads)
        # ! 1---3---5   u:->+ 
        # ! |##/|##/|      
        # ! |#/ |#/ |   v:|
        # ! |/  |/  |     V
        # ! 2---4---*     +

        u = ((index - 1) % w) + 1
        v = div((index - 1), w) + 1

        a = self._vertexes[u  ,v  ]
        b = self._vertexes[u  ,v+1]
        c = self._vertexes[u+1,v  ]

        return PTriangle(a,b,c)
    elseif (index <= 2 * number_of_quads)
        # ! *---3---4   u:->+ 
        # ! |  /|  /|      
        # ! | /#| /#|   v:|
        # ! |/##|/##|     V
        # ! 1---2---3     +

        u = ((index - 1) % w) + 1
        v = (div((index - 1), w) - h) + 1 + 1

        a = self._vertexes[u  ,v  ]
        b = self._vertexes[u+1,v  ]
        c = self._vertexes[u+1,v-1]
        
        return PTriangle(a,b,c)
    else
        return nothing
    end
end

function Base.copy!(a::FlatMatrix{T1},b::FlatMatrixManager{T2},layer) where {T1,T2}
    for u in 1:width(a)
        for v in 1:height(a)
            b[layer,u,v] = T2(a[u,v])
        end
    end
end
