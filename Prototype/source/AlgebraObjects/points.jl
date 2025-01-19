
mutable struct Point_Plan <: JuliAgebra.RenderPlan
    _coords::Vec3F
end

mutable struct Point <:AlgebraObject
    _coords::Vec3F
    _soil::Function

    function Point(coords::Vec3F)
        new(coords,() -> nothing)
    end

end

Base.string(self::Point) = "Point"

mutable struct Point_Employee <:RenderEmployee
    _asset::Point
    _dirty::Bool
    _openglD::OpenGLData
    _data::Vector{Vec3F}
    _bufferArray::BufferArray

    function Point_Employee(asset::Point,openglD::OpenGLData,data::Vector{Vec3F})
        
        bufferArray = BufferArray(Vec3F,GL_STATIC_DRAW,data)
        
        dirty = false
        self = new(asset,dirty,openglD,data,bufferArray)
        asset._soil = () -> soil(employee)
        
        myVector = get!(openglD._renderOffices,Movable_Limited_Employee,Vector{Movable_Limited_Employee}())
        push!(myVector,self)        
    
    end
end

Base.string(self::Point_Employee)="Point_Employee"
Base.string(self::Type{Point_Employee}) = "Type: Point_Employee"

function soil(self::Point_Employee)
    if !self._dirty
        self._dirty = true
        # * Notify openglData that I'm dirty by queuing myself.
        enqueue!(self._openglD._updateMeQueue,self)
    end
end

sanitize!(self::Point_Employee) = (self._dirty = false; _sanitize!(self))
_sanitize!(self::Point_Employee) = upload!(self._bufferArray,self._data)

function recruit!(self::OpenGLData,plan::Point_Plan)::Point
    vertexes = deepcopy(plan._vertexes)
    asset = Movable_Limited_Body(view(vertexes, : ))
    Movable_Limited_Employee(asset,self,vertexes)
    return asset
end

draw!(self::Point_Employee) = draw(self._bufferArray,GL_TRIANGLES)
destroy!(self::Point_Employee) = destroy!(self._bufferArray)


export Point_Plan