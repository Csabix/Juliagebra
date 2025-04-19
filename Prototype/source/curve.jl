
# ? ---------------------------------
# ! ParametricCurveAlgebra
# ? ---------------------------------

mutable struct ParametricCurveAlgebra <: AlgebraDNA
    _algebra::Algebra
    
    _tStart::Float64
    _tEnd::Float64
    _tNum::Int
    
    _startIndex::Int
    _endIndex::Int
    _tValues::Vector{Vec3F}

    _color::Vec3F

    function ParametricCurveAlgebra(renderer,dependents::Vector{PlanDNA},callback::Function,color::Vec3F)
        a = Algebra(renderer,dependents,callback)
        
        new(a,0,0,0,0,0,[],Vec3FNan)
    end
end

Base.string(self::ParametricCurveAlgebra)::String =  return "ParametricCurve: $(self._startIndex) - $(self._endIndex) - $(self._tNum)"
_Algebra_(self::ParametricCurveAlgebra)::Algebra = return self._algebra

function _callback(self::ParametricCurveAlgebra)
    
    # TODO broadcasttal megoldva (mint numpyban).
    # TODO indexeket 1 tömbbe

    for index in self._startIndex:self._endIndex
        t1 = Float64(index - self._startIndex)
        t2 = Float64(self._endIndex - self._startIndex)
        t = (t1 / t2) * (self._tEnd - self._tStart) + self._tStart
        
        x,y,z = _Algebra_(self)._callback(t,_Algebra_(self)._dependents...)
        self._tValues[index] = Vec3F(x,y,z)
    end
end

function callback(self::ParametricCurveAlgebra)
    _callback(self)
    flag!(self)
end

# ? ---------------------------------
# ! ParametricCurvePlan
# ? ---------------------------------

mutable struct ParametricCurvePlan <: PlanDNA
    _tStart::Float64
    _tEnd::Float64
    _tNum::Int
    
    _plan::Plan
    _plans::Vector{PlanDNA}
    _color::Vec3F
    _callback::Function

    function ParametricCurvePlan(tStart,tEnd,tNum,plans::Vector{T},callback::Function,color) where {T<:PlanDNA}

        r = Float32(color[1])
        g = Float32(color[2])
        b = Float32(color[3])

        new(tStart,tEnd,tNum,Plan(),plans,Vec3F(r,g,b),callback)
    end
end

_Plan_(self::ParametricCurvePlan)::Plan = return self._plan

# ? ---------------------------------
# ! CurveRenderer
# ? ---------------------------------

mutable struct CurveRenderer <: RendererDNA{ParametricCurveAlgebra}
    _renderer::Renderer{ParametricCurveAlgebra}

    _shader::ShaderProgram
    _buffer::TypedBufferArray

    _coords::Vector{Vec3F}
    _colors::Vector{Vec3F}

    function CurveRenderer(context::OpenGLData)
        
        renderer = Renderer{ParametricCurveAlgebra}(context)

        shader = ShaderProgram(sp("rounded_curve_colored.vert"),sp("rounded_curve.geom"),sp("rounded_curve.frag"),["VP"])
        buffer = TypedBufferArray{Tuple{Vec3F,Vec3F}}()

        coords = Vector{Vec3F}()
        colors = Vector{Vec3F}()

        new(
            renderer,
            shader,
            buffer,
            coords,
            colors)
    end
end

_Renderer_(self::CurveRenderer) = return self._renderer
Base.string(self::CurveRenderer) = return "CurveRenderer[$(length(self._coords))]"

function added!(self::CurveRenderer,curve::ParametricCurveAlgebra)
    curve._startIndex = length(self._coords) + 1
    
    for i in 1:curve._tNum
        push!(self._coords,Vec3F(0,0,0))
        push!(self._colors,curve._color)
    end
    push!(self._coords,Vec3FNan)
    push!(self._colors,Vec3FNan)

    
    curve._endIndex = length(self._coords) - 1
    curve._tValues = self._coords

    _callback(curve)

    println("Added Curve as: $(curve._startIndex) - $(curve._endIndex) - $(curve._tNum)")
end

function addedUpload!(self::CurveRenderer)
    upload!(self._buffer,1,self._coords,GL_DYNAMIC_DRAW)
    upload!(self._buffer,2,self._colors,GL_DYNAMIC_DRAW)

end

function sync!(self::CurveRenderer,curve::ParametricCurveAlgebra)
    println("Synced Curve!")
end

function syncUpload!(self::CurveRenderer)
    upload!(self._buffer,1,self._coords,GL_DYNAMIC_DRAW)
end

function draw!(self::CurveRenderer,vp,selectedID,pickedID,cam,shrd)
    vp,v,p = getMat(cam,shrd._width,shrd._height)
    
    activate(self._shader)
    setUniform!(self._shader,"VP",vp)
    draw(self._buffer,GL_LINE_STRIP)
end

function destroy!(self::CurveRenderer)
    destroy!(self._shader)
    destroy!(self._buffer)
end

function plan2Algebra(self::CurveRenderer,plan::ParametricCurvePlan)::ParametricCurveAlgebra
    curve = ParametricCurveAlgebra(self,plan._plans,plan._callback,plan._color)
    
    curve._tStart   = plan._tStart
    curve._tEnd     = plan._tEnd
    curve._tNum     = plan._tNum
    curve._color    = plan._color

    return curve
end

function recruit!(self::OpenGLData,plan::ParametricCurvePlan)::ParametricCurveAlgebra
    myVector = get!(self._renderOffices,CurveRenderer,Vector{CurveRenderer}())
    if(length(myVector)!=1)
        push!(myVector,CurveRenderer(self))
    end

    curve = assignPlan!(myVector[1],plan)
    return curve
end