

# ! Movable = able to move the object
# ! Limited = Fix sized

mutable struct Movable_Limited_Plan <: JuliAgebra.RenderPlan
    _vertexes::Vector{Vec3}
end

mutable struct Movable_Limited_Body <:AlgebraObject
    _vertexes::AbstractArray{Vec3,1} 
    _dirty::Bool

    function Movable_Limited_Body(vertexes)
        new(vertexes,false)
    end

end

Base.string(self::Movable_Limited_Body)="Movable_Limited_Body"

_soil!(self::Movable_Limited_Body) = (self._dirty = true)
soiled(self::Movable_Limited_Body) = self._dirty
sanitize(self::Movable_Limited_Body) = (self._dirty = false)

function Base.setindex!(self::Movable_Limited_Body,value::Vec3,key)
    vec = self._vertexes[key]
    vec.x = value.x
    vec.y = value.y
    vec.z = value.z
    _soil!(self)
end

mutable struct Movable_Limited_Employee <:RenderEmployee
    _assets::Movable_Limited_Body
    _gpuBuffer::Vector{Vec3}

    function Movable_Limited_Employee(asset::Movable_Limited_Body,vertexes::Vector{Vec3})
        # ! GPU construction data can come here
        new(asset,vertexes)
    end

end

Base.string(self::Movable_Limited_Employee)="Movable_Limited_Employee"

function actualize!(self::Movable_Limited_Employee)
    sanitize(self._assets)
end


function recruit!(self::OpenGLData,plan::Movable_Limited_Plan)
    vertexes = deepcopy(plan._vertexes)
    #println(vertexes)
    asset = Movable_Limited_Body(view(vertexes, : ))
    employee = Movable_Limited_Employee(asset,vertexes)
    myVector = get!(self._renderOffices,Movable_Limited_Employee,Vector{Movable_Limited_Employee}())
    push!(myVector,employee)
end

export Movable_Limited_Plan