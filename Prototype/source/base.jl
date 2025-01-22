
function relativePath()::String
    myPath = (@__FILE__)
    myPath = myPath[1:(length(myPath) - length("base.jl"))]
    return myPath
end

mutable struct SuperAlgebra
    _renderer::Renderers
    _rendererID::Int

    _dependents::Vector{Algebras}
    _graph::Vector{Algebras}

    _callback::Function

    function SuperAlgebra(renderer::Renderers,rendererID::Int,planDependents::Vector{Plans},callback::Function)
        algebraDependents = Vector{Algebras}()
        
        for plan in planDependents
            push!(algebraDependents,algebra(plan))
        end

        new(renderer,rendererID,algebraDependents,Vector{Algebras}(),callback)
    end

end

super(self::Algebras)::SuperAlgebra = error("Create \"super!(self)\" func for Algebras!")

function soilOnlyOnce!(self::Algebras)
    self_super = super(self)
    soil!(self_super._renderer,self)
end

mutable struct Point <: Algebras
    _parent::SuperAlgebra
    _x::Float64
    _y::Float64
    _z::Float64    

    function Point(renderer,rendererID::Int,dependents::Vector{Plans},callback::Function)
        p = SuperAlgebra(renderer,rendererID,dependents,callback)
        new(p,0,0,0)
    end
end

super(self::Point)::SuperAlgebra = return self._parent
Base.string(self::Point) = "Point[$(super(self)._rendererID) - $(string(length(super(self)._dependents))) - $(string(length(super(self)._graph)))]($(self._x),$(self._y),$(self._z))"

function set(self::Point,x::Float64,y::Float64,z::Float64)
    self._x = x
    self._y = y
    self._z = z
    soilOnlyOnce!(self)
end

mutable struct SuperRenderer
    _context::OpenGLData
    _shader::ShaderProgram
    _parentLock::QueueLock

    function SuperRenderer(context::OpenGLData,shader::ShaderProgram) 
        new(context,shader,QueueLock())
    end
end

function destroy!(self::SuperRenderer)
    destroy!(self._shader)
end

super(self::Renderers)::SuperRenderer   = error("Create \"super!(self)\" func for Renderers!")
_update!(self::Renderers)               = error("Create \"_update!(self)\" func for Renderers!")
_draw!(self::Renderers)                 = error("Create \"_draw!(self)\" func for Renderers!")
_destroy!(self::Renderers)              = error("Create \"_destroy!(self)\" func for Renderers!")

function soil!(self::Renderers)
    self_super = super(self)
    lock(self_super._parentLock,self_super._context._updateMeQueue,self)
end

function update!(self::Renderers)
    _update!(self)
    unlock(super(self)._parentLock)
end

function draw!(self::Renderers,vp,selectedID,pickedID)
    activate(super(self)._shader)
    setUniform!(super(self)._shader,"VP",vp)
    setUniform!(super(self)._shader,"selectedID",selectedID)
    setUniform!(super(self)._shader,"pickedID",pickedID)
    _draw!(self)
end

function destroy!(self::Renderers)
    destroy!(super(self))
    _destroy!(self)
end

mutable struct PointRenderer <: Renderers
    _parent::SuperRenderer
    _buffer::BufferArray
    _points::Vector{Point}
    _queue::Queue{Point}
    _coords::Vector{Vec4F}

    _nextRendererID::Int

    function PointRenderer(context::OpenGLData) 
        rp = relativePath()
        shader = ShaderProgram(rp * "Shaders/point.vert",rp * "Shaders/point.frag",["VP","selectedID","pickedID"])
        parent = SuperRenderer(context,shader)

        buffer = BufferArray(Vec4F,GL_DYNAMIC_DRAW)
        
        points = Vector{Point}()
        queue = Queue{Point}()
        coords = Vector{Vec4F}()

        new(
            parent,
            buffer,
            points,
            queue,
            coords,
            ID_LOWER_BOUND+1)
    end
end

super(self::PointRenderer) = return self._parent
Base.string(self::PointRenderer) = return "PointRenderer($(length(self._points)))"

function _update!(self::PointRenderer)
    while !isempty(self._queue)
        point = dequeue!(self._queue)
        println("Updating point: $(string(point))")
        id = super(point)._rendererID
        x = point._x
        y = point._y
        z = point._z
        self._coords[id-ID_LOWER_BOUND] = Vec4F(x,y,z,id)
    end
    upload!(self._buffer,self._coords)
end

function fetch(self::PointRenderer, id)
    return self._points[id-ID_LOWER_BOUND]
end

function soil!(self::PointRenderer,item::Point)
    enqueue!(self._queue,item)
    soil!(self)
end

_draw!(self::PointRenderer) = draw(self._buffer,GL_POINTS)
_destroy!(self::PointRenderer) = destroy!(self._buffer)

mutable struct PointPlan <: Plans
    x::Float64
    y::Float64
    z::Float64
    _item::Union{Nothing,Point}
    _plans::Vector{Plans}
    _callback::Function
end

algebra(self::PointPlan)::Algebras = return self._item
Base.string(self::PointPlan)::String = return "PointPlan[$(string(length(self._plans)))] -> $(string(self._item))"

function recruit!(self::OpenGLData, plan::PointPlan)::Point
    myVector = get!(self._renderOffices,PointRenderer,Vector{PointRenderer}())
    
    if(length(myVector)!=1)
        push!(myVector,PointRenderer(self))
    end

    point = add!(myVector[1],plan)
    plan._item = point
    return point
end

function add!(self::PointRenderer,plan::PointPlan)::Point
    
    newPoint = Point(self,self._nextRendererID,plan._plans,plan._callback)
    newPoint._x = plan.x
    newPoint._y = plan.y
    newPoint._z = plan.z

    push!(self._coords,Vec4F(0,0,0,0))
    push!(self._points,newPoint)
    
    soilOnlyOnce!(newPoint)
    
    self._nextRendererID+=1

    return newPoint
end

export PointPlan