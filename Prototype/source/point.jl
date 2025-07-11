
# ? ---------------------------------
# ! PointPlan
# ? ---------------------------------

mutable struct PointPlan <: RenderedPlanDNA
    _plan::RenderedPlan
    
    _x::Float64
    _y::Float64
    _z::Float64
    

    function PointPlan(callback::Function,plans::Vector{T},x,y,z) where {T<:PlanDNA}
        new(RenderedPlan(callback,plans),
            x,y,z)
    end
end

_RenderedPlan_(self::PointPlan)::RenderedPlan = return self._plan
Base.string(self::PointPlan)::String = return "PointPlan[$(string(length(self._plans)))] -> $(string(_Plan_(self)._algebra))"

# ? ---------------------------------
# ! PointAlgebra
# ? ---------------------------------

mutable struct PointAlgebra <:RenderedAlgebraDNA
    _renderedAlgebra::RenderedAlgebra
    _x::Float64
    _y::Float64
    _z::Float64    

    function PointAlgebra(plan::PointPlan)
        a = RenderedAlgebra(plan)
        x = plan._x
        y = plan._y
        z = plan._z
        new(a,x,y,z)
    end
end


# ! Must have
function Plan2Algebra(plan::PointPlan)::PointAlgebra
    return PointAlgebra(plan)
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

getPointField(self::PointAlgebra,fieldVal::Val{:x}) = return self._x
getPointField(self::PointAlgebra,fieldVal::Val{:y}) = return self._y
getPointField(self::PointAlgebra,fieldVal::Val{:z}) = return self._z
getPointField(self::PointAlgebra,fieldVal) = error("Unrecognized Symbol for Point's field!")
Base.getindex(self::PointAlgebra,fieldSymbol::Symbol) = return getPointField(self,Val(fieldSymbol))

function Base.getindex(self::PointAlgebra,fieldSymbols...)
    
    fieldValues = []

    for fieldSymbol in fieldSymbols
        push!(fieldValues,self[fieldSymbol])
    end

    return tuple(fieldValues...)
end

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

    println("Added point as: x: $(x)\ty: $(y)\tz: $(z)\trID: $(_RenderedAlgebra_(point)._rendererID)\taID: $(aID)")
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