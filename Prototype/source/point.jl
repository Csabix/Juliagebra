
function pointRelativePath()::String
    myPath = (@__FILE__)
    myPath = myPath[1:(length(myPath) - length("point.jl"))]
    return myPath
end


# ? ---------------------------------
# ! PointAlgebra
# ? ---------------------------------

mutable struct PointAlgebra <:€Algebra
    _algebra::Algebra
    _x::Float64
    _y::Float64
    _z::Float64    

    function PointAlgebra(renderer,rendererID::Int,dependents::Vector{€Plan},callback::Function)
        a = Algebra(renderer,rendererID,dependents,callback)
        new(a,0,0,0)
    end
end

_Algebra_(self::PointAlgebra)::Algebra = return self._algebra
Base.string(self::PointAlgebra) = "Point[$(_Algebra_(self)._rendererID) - $(string(length(_Algebra_(self)._dependents))) - $(string(length(_Algebra_(self)._graph)))]($(self._x),$(self._y),$(self._z))"

function set(self::PointAlgebra,x::Float64,y::Float64,z::Float64)
    self._x = x
    self._y = y
    self._z = z
    
    senqueue!(self)
    
    for item in _Algebra_(self)._graph
        callback(item)
    end
end

x(self::PointAlgebra) = return self._x
y(self::PointAlgebra) = return self._y
z(self::PointAlgebra) = return self._z

function callback(self::PointAlgebra)
    x,y,z = _Algebra_(self)._callback(_Algebra_(self)._dependents...)
    
    # TODO: Multiple-Dispatch on _callback return
    
    self._x = Float64(x)
    self._y = Float64(y)
    self._z = Float64(z)
    
    senqueue!(self)
end

# ? ---------------------------------
# ! PointPlan
# ? ---------------------------------

mutable struct PointPlan <:€Plan
    x::Float64
    y::Float64
    z::Float64
    _algebra::Union{Nothing,PointAlgebra}
    _plans::Vector{€Plan}
    _callback::Function
end

_Algebra_(self::PointPlan)::€Algebra = return self._algebra
Base.string(self::PointPlan)::String = return "PointPlan[$(string(length(self._plans)))] -> $(string(self._algebra))"

# ? ---------------------------------
# ! PointRenderer
# ? ---------------------------------

mutable struct PointRenderer <:€Renderer{PointAlgebra}
    _renderer::Renderer{PointAlgebra}

    _shader::ShaderProgram
    _buffer::BufferArray
    
    _points::Vector{PointAlgebra}
    _coords::Vector{Vec4F}

    _nextRendererID::Int

    function PointRenderer(context::OpenGLData) 
        rp     = pointRelativePath()
        
        shader = ShaderProgram(rp * "Shaders/point.vert",rp * "Shaders/point.frag",["VP","selectedID","pickedID"])
        renderer = Renderer{PointAlgebra}(context)

        buffer = BufferArray(Vec4F,GL_DYNAMIC_DRAW)
        
        points = Vector{PointAlgebra}()
        coords = Vector{Vec4F}()

        new(
            renderer,
            shader,
            buffer,
            points,
            coords,
            ID_LOWER_BOUND+1)
    end
end

_Renderer_(self::PointRenderer) = return self._renderer
Base.string(self::PointRenderer) = return "PointRenderer($(length(self._points)))"

function update!(self::PointRenderer)
    while !isempty(self._renderer._algebraQueue)
        point = sdequeue!(self._renderer._algebraQueue)
        println("Updating point: $(string(point))")
        id = _Algebra_(point)._rendererID
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

function draw!(self::PointRenderer,vp,selectedID,pickedID) 
    activate(self._shader)
    setUniform!(self._shader,"VP",vp)
    setUniform!(self._shader,"selectedID",selectedID)
    setUniform!(self._shader,"pickedID",pickedID)
    draw(self._buffer,GL_POINTS)
end

function destroy!(self::PointRenderer) 
    destroy!(self._shader)
    destroy!(self._buffer)
end

function add!(self::PointRenderer,plan::PointPlan)::PointAlgebra
    
    newPoint = PointAlgebra(self,self._nextRendererID,plan._plans,plan._callback)
    newPoint._x = plan.x
    newPoint._y = plan.y
    newPoint._z = plan.z

    push!(self._coords,Vec4F(0,0,0,0))
    push!(self._points,newPoint)
    
    senqueue!(newPoint)
    
    self._nextRendererID+=1

    return newPoint
end

function recruit!(self::OpenGLData, plan::PointPlan)::PointAlgebra
    myVector = get!(self._renderOffices,PointRenderer,Vector{PointRenderer}())
    
    if(length(myVector)!=1)
        push!(myVector,PointRenderer(self))
    end

    point = add!(myVector[1],plan)
    plan._algebra = point
    return point
end

export PointPlan
export x,y,z