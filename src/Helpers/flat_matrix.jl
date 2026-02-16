
mutable struct FlatMatrix{T}
    _manager::FlatMatrixManager{T}
    _layer::UInt32

    function FlatMatrix{T}(layer::Int,manager::FlatMatrixManager{T}) where T
        new(manager,UInt32(layer))
    end
end

function Base.getindex(self::FlatMatrix{T},u,v)::T where T
    return self._manager[self._layer,u,v]
end

function Base.setindex!(self::FlatMatrix{T},item::T,u,v) where T
    self._manager[self._layer,u,v] = item
end

Base.string(self::FlatMatrix{T}) where T = return "$(self._manager)[$(self._layer)]{$(T)}"

height(self::FlatMatrix{T}) where T = return height(self._manager,self._layer)
width(self::FlatMatrix{T}) where T = return width(self._manager,self._layer)

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

const EMPTY_FlatMatrix = FlatMatrix{Vec3F}(0,FlatMatrixManager{Vec3F}())