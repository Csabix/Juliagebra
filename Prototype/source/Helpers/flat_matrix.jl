
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
        abc = (a,b,c)

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
        abc = (a,b,c)

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

function Base.getindex(self::TrianglesOf,index)::Union{Nothing, Tuple{Vec3F, Vec3F, Vec3F}}
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

        #println("u: ", u, "  v: ", v, "  w: ", w, "  h: ", h)
        
        a = self._vertexes[u  ,v  ]
        b = self._vertexes[u  ,v+1]
        c = self._vertexes[u+1,v  ]

        return (a,b,c)
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
        
        return (a,b,c)
    else
        return nothing
    end
end

const EMPTY_FlatMatrix = FlatMatrix{0,Vec3F}(FlatMatrixManager{Vec3F}())