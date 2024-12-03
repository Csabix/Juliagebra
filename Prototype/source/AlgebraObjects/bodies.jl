

# ! Movable = able to move the object
# ! Limited = Fix sized

mutable struct Movable_Limited_Plan <: JuliAgebra.RenderPlan
    _vertexes::Vector{Vec3F}
end

mutable struct Movable_Limited_Body <:AlgebraObject
    _vertexes::AbstractArray{Vec3F,1} 
    _soil::Function

    function Movable_Limited_Body(vertexes)
        new(vertexes,() -> nothing)
    end

end

Base.string(self::Movable_Limited_Body) = "Movable_Limited_Body[$(length(self._vertexes))]"

function Base.setindex!(self::Movable_Limited_Body,value::Vec3,key)
    vec = self._vertexes[key]
    vec.x = value.x
    vec.y = value.y
    vec.z = value.z
    self._soil()
end

mutable struct Movable_Limited_Employee <:RenderEmployee
    _asset::Movable_Limited_Body
    _dirty::Bool
    _openglD::OpenGLData
    _data::Vector{Vec3F}
    _bufferArray::BufferArray

    function Movable_Limited_Employee(asset::Movable_Limited_Body,openglD::OpenGLData,data::Vector{Vec3F})
        
        bufferArray = BufferArray(Vec3F,GL_STATIC_DRAW,data)
        
        dirty = false
        self = new(asset,dirty,openglD,data,bufferArray)
        asset._soil = () -> soil(employee)
        
        # * Merging this bad boy into openglData
        myVector = get!(openglD._renderOffices,Movable_Limited_Employee,Vector{Movable_Limited_Employee}())
        push!(myVector,self)        
    
    end
end

Base.string(self::Movable_Limited_Employee)="Movable_Limited_Employee"
Base.string(self::Type{Movable_Limited_Employee}) = "Type: Movable_Limited_Employee"

function soil(self::Movable_Limited_Employee)
    if !self._dirty
        self._dirty = true
        # * Notify openglData that I'm dirty by queuing myself.
        enqueue!(self._openglD._updateMeQueue,self)
    end
end

sanitize!(self::Movable_Limited_Employee) = (self._dirty = false; _sanitize!(self))
_sanitize!(self::Movable_Limited_Employee) = upload!(self._bufferArray,self._data)

function recruit!(self::OpenGLData,plan::Movable_Limited_Plan)::Movable_Limited_Body
    vertexes = deepcopy(plan._vertexes)
    asset = Movable_Limited_Body(view(vertexes, : ))
    Movable_Limited_Employee(asset,self,vertexes)
    return asset
end

draw!(self::Movable_Limited_Employee) = draw(self._bufferArray,GL_TRIANGLES)
destroy!(self::Movable_Limited_Employee) = destroy!(self._bufferArray)


export Movable_Limited_Plan