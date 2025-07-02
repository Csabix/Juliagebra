
# ? ---------------------------------
# ! PointPlan
# ? ---------------------------------

mutable struct PointPlan <: RenderedPlanDNA
    x::Float64
    y::Float64
    z::Float64
    _plan::Plan

    function PointPlan(x,y,z,plans::Vector{T},callback::Function) where {T<:PlanDNA}
        new(x,y,z,Plan(plans,callback))
    end
end

_Plan_(self::PointPlan)::Plan = return self._plan
Base.string(self::PointPlan)::String = return "PointPlan[$(string(length(self._plans)))] -> $(string(_Plan_(self)._algebra))"

# ? ---------------------------------
# ! PointAlgebra
# ? ---------------------------------

mutable struct PointAlgebra <:RenderedAlgebraDNA
    _renderedAlgebra::RenderedAlgebra
    _x::Float64
    _y::Float64
    _z::Float64    
    _rendererID::Int

    function PointAlgebra(plan::PointPlan,renderer)
        a = RenderedAlgebra(plan,renderer)
        x = plan.x
        y = plan.y
        z = plan.z
        new(a,x,y,z,0)
    end
end


# ! Must have
function Plan2Algebra(plan::PointPlan,renderer)::PointAlgebra
    return PointAlgebra(plan,renderer)
end

_RenderedAlgebra_(self::PointAlgebra)::RenderedAlgebra = return self._renderedAlgebra
Base.string(self::PointAlgebra) = "Point[$(_Algebra_(self)._graphID) - $(string(length(_Algebra_(self)._graphParents))) - $(string(length(_Algebra_(self)._graphChain)))]($(self._x),$(self._y),$(self._z))"

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
    return _Algebra_(self)._callback(_Algebra_(self)._graphParents...)
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
# ! PointRenderer
# ? ---------------------------------

mutable struct PointRenderer <:RendererDNA{PointAlgebra}
    _renderer::Renderer{PointAlgebra}

    _shader::ShaderProgram
    _buffer::TypedBufferArray    
    
    _coords::Vector{Vec3F}
    _ids::Vector{Float32}
    
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
            ids)
    end
end

_Renderer_(self::PointRenderer) = return self._renderer
Base.string(self::PointRenderer) = return "PointRenderer($(length(self._ids)))"

# ! Must have
function added!(self::PointRenderer,point::PointAlgebra)
    aID = _Algebra_(point)._graphID

    x = point._x
    y = point._y
    z = point._z

    push!(self._coords,Vec3F(x,y,z))
    push!(self._ids,Float32(aID))

    println("Added point as: x: $(x)\ty: $(y)\tz: $(z)\trID: $(point._rendererID)\taID: $(aID)")
end

# ! Must have
function addedUpload!(self::PointRenderer)
    upload!(self._buffer,2,self._ids,GL_STATIC_DRAW)
    println("Uploaded ID buffer!")
end

# ! Must have
function sync!(self::PointRenderer,point::PointAlgebra)
    id = point._renderedAlgebra._rendererID
    x = point._x
    y = point._y
    z = point._z
    self._coords[id] = Vec3F(x,y,z)
    println("Synced point as: x: $(x)\ty: $(y)\tz: $(z)\trID: $(id)")
end

# ! Must have
function syncUpload!(self::PointRenderer)
    upload!(self._buffer,1,self._coords,GL_DYNAMIC_DRAW)
    println("Uploaded Coordinate buffer!")
end

# ! Must have
function draw!(self::PointRenderer,vp,selectedID,pickedID,cam,shrd) 
    activate(self._shader)
    setUniform!(self._shader,"VP",vp)
    setUniform!(self._shader,"selectedID",selectedID)
    setUniform!(self._shader,"pickedID",pickedID)
    draw(self._buffer,GL_POINTS)
end

# ! Must have
function destroy!(self::PointRenderer) 
    destroy!(self._shader)
    destroy!(self._buffer)
end

# ! Must have
function Plan2Renderer(self::OpenGLData,plan::PointPlan)
    return SingleRendererTactic(self,PointRenderer)
end

export x,y,z