
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