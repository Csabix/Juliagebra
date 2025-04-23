

# ? ---------------------------------
# ! PointAlgebra
# ? ---------------------------------

mutable struct PointAlgebra <:RenderedAlgebraDNA
    _renderedAlgebra::RenderedAlgebra
    _x::Float64
    _y::Float64
    _z::Float64    
    _rendererID::Int

    function PointAlgebra(renderer,dependents::Vector{PlanDNA},callback::Function)
        a = RenderedAlgebra(renderer,dependents,callback)
        new(a,0,0,0,0)
    end
end

_RenderedAlgebra_(self::PointAlgebra)::RenderedAlgebra = return self._renderedAlgebra
Base.string(self::PointAlgebra) = "Point[$(_Algebra_(self)._algebraID) - $(string(length(_Algebra_(self)._dependents))) - $(string(length(_Algebra_(self)._graph)))]($(self._x),$(self._y),$(self._z))"

# TODO: Move set to RenderedAlgebra

function set(self::PointAlgebra,x::Float64,y::Float64,z::Float64)
    self._x = x
    self._y = y
    self._z = z
    
    flag!(self)
    
    evalGraph(self)

end

x(self::PointAlgebra) = return self._x
y(self::PointAlgebra) = return self._y
z(self::PointAlgebra) = return self._z

function evalCallback(self::PointAlgebra)
    return _Algebra_(self)._callback(_Algebra_(self)._dependents...)
end

function dpCallbackReturn(self::PointAlgebra,v)
    x,y,z = v
    self._x = Float64(x)
    self._y = Float64(y)
    self._z = Float64(z)
    
    flag!(self)
end

function dpCallbackReturn(self::PointAlgebra,undef::Undef)
    
    self._x = NaN64
    self._y = NaN64
    self._z = NaN64
    
    flag!(self)
end

onGraphEval(self::PointAlgebra) = dpEvalCallback(self)

# ? ---------------------------------
# ! PointPlan
# ? ---------------------------------

mutable struct PointPlan <:PlanDNA
    x::Float64
    y::Float64
    z::Float64
    _plan::Plan
    _plans::Vector{PlanDNA}
    _callback::Function

    function PointPlan(x,y,z,plans::Vector{T},callback::Function) where {T<:PlanDNA}
        new(x,y,z,Plan(),plans,callback)
    end
end

_Plan_(self::PointPlan)::Plan = return self._plan
Base.string(self::PointPlan)::String = return "PointPlan[$(string(length(self._plans)))] -> $(string(_Plan_(self)._algebra))"

# ? ---------------------------------
# ! PointRenderer
# ? ---------------------------------

mutable struct PointRenderer <:RendererDNA{PointAlgebra}
    _renderer::Renderer{PointAlgebra}

    _shader::ShaderProgram
    _buffer::TypedBufferArray    
    _coords::Vector{Vec3F}
    _ids::Vector{Float32}
    
    _nextRendererID::Int

    function PointRenderer(context::OpenGLData) 
        
        shader = ShaderProgram(sp("point.vert"),sp("point.frag"),["VP","selectedID","pickedID"])
        renderer = Renderer{PointAlgebra}(context)

        buffer = TypedBufferArray{Tuple{Vec3F,Float32}}()
        coords = Vector{Vec3F}()
        ids    = Vector{Float32}()

        new(
            renderer,
            shader,
            buffer,
            coords,
            ids,
            1)
    end
end

_Renderer_(self::PointRenderer) = return self._renderer
Base.string(self::PointRenderer) = return "PointRenderer($(self._nextRendererID - 1))"

function added!(self::PointRenderer,point::PointAlgebra)
    
    point._rendererID = self._nextRendererID
    self._nextRendererID+=1

    x   = point._x
    y   = point._y
    z   = point._z
    aID = _Algebra_(point)._algebraID

    push!(self._coords,Vec3F(x,y,z))
    push!(self._ids,Float32(aID))

    println("Added point as: x: $(x)\ty: $(y)\tz: $(z)\trID: $(point._rendererID)\taID: $(aID)")
end

function addedUpload!(self::PointRenderer)
    upload!(self._buffer,2,self._ids,GL_STATIC_DRAW)
    println("Uploaded ID buffer!")
end

function sync!(self::PointRenderer,point::PointAlgebra)
    id = point._rendererID
    x = point._x
    y = point._y
    z = point._z
    self._coords[id] = Vec3F(x,y,z)
    println("Synced point as: x: $(x)\ty: $(y)\tz: $(z)\trID: $(id)")
end

function syncUpload!(self::PointRenderer)
    upload!(self._buffer,1,self._coords,GL_DYNAMIC_DRAW)
    println("Uploaded Coordinate buffer!")
end

function draw!(self::PointRenderer,vp,selectedID,pickedID,cam,shrd) 
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

function plan2Algebra(self::PointRenderer,plan::PointPlan)::PointAlgebra
    
    newPoint = PointAlgebra(self,plan._plans,plan._callback)
    newPoint._x = plan.x
    newPoint._y = plan.y
    newPoint._z = plan.z

    return newPoint
end


function recruit!(self::OpenGLData, plan::PointPlan)::PointAlgebra
    myVector = get!(self._renderOffices,PointRenderer,Vector{PointRenderer}())
    
    if(length(myVector)!=1)
        push!(myVector,PointRenderer(self))
    end

    point = assignPlan!(myVector[1],plan)
    return point
end

export x,y,z