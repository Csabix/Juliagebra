# ? ---------------------------------
# ! ParametricCurvePlan
# ? ---------------------------------

mutable struct ParametricCurvePlan <: RenderedPlanDNA
    _plan::RenderedPlan

    _tStart::Float64
    _tEnd::Float64
    _tNum::Int
    _color::Vec3F
    
    function ParametricCurvePlan(callback::Function,plans::Vector{T},tStart,tEnd,tNum,color) where {T<:PlanDNA}

        r = Float32(color[1])
        g = Float32(color[2])
        b = Float32(color[3])

        new(RenderedPlan(callback,plans),tStart,tEnd,tNum,Vec3F(r,g,b))
    end
end

Base.string(self::PointPlan)::String = return "Curve"
_RenderedPlan_(self::PointPlan)::RenderedPlan = return self._plan

# ? ---------------------------------
# ! ParametricCurveAlgebra
# ? ---------------------------------

mutable struct ParametricCurveAlgebra <: RenderedAlgebraDNA
    _renderedAlgebra::RenderedAlgebra
    
    _tStart::Float64
    _tEnd::Float64
    _tNum::Int
    _color::Vec3F

    _startIndex::Int
    _endIndex::Int
    _tValues::Vector{Vec3F}

    

    function ParametricCurveAlgebra(plan::ParametricCurvePlan)
        a = RenderedAlgebra(plan)
        tStart = plan._tStart
        tEnd = plan._tEnd
        tNum = plan._tNum
        color = plan._color

        new(a,tStart,tEnd,tNum,color,0,0,[])
    end
end

# ! Must have
function Plan2Algebra(plan::ParametricCurvePlan)::ParametricCurveAlgebra
    return ParametricCurveAlgebra(plan)
end

Base.string(self::ParametricCurveAlgebra)::String =  return "ParametricCurve: $(self._startIndex) - $(self._endIndex) - $(self._tNum)"
_RenderedAlgebra_(self::ParametricCurveAlgebra)::RenderedAlgebra = return self._renderedAlgebra

function evalCallback(self::ParametricCurveAlgebra,t,index)
    return _Algebra_(self)._callback(t,_Algebra_(self)._dependents...)
end

dpCallbackReturn(self::ParametricCurveAlgebra,t,index,v::Tuple)     = ((x,y,z) = v ; self._tValues[index] = Vec3F(x,y,z))
dpCallbackReturn(self::ParametricCurveAlgebra,t,index,undef::Undef) = self._tValues[index] = Vec3FNan

function runCallbacks(self::ParametricCurveAlgebra)
    for index in self._startIndex:self._endIndex
        t1 = Float64(index - self._startIndex)
        t2 = Float64(self._endIndex - self._startIndex)
        t = (t1 / t2) * (self._tEnd - self._tStart) + self._tStart
        dpEvalCallback(self,t,index)
    end
end

function onGraphEval(self::ParametricCurveAlgebra)
    runCallbacks(self)
    flag!(self)
end

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

# ! Must have
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

    runCallbacks(curve)

    println("Added Curve as: $(curve._startIndex) - $(curve._endIndex) - $(curve._tNum)")
end

# ! Must have
function addedUpload!(self::CurveRenderer)
    upload!(self._buffer,1,self._coords,GL_DYNAMIC_DRAW)
    upload!(self._buffer,2,self._colors,GL_STATIC_DRAW)

end

# ! Must have
function sync!(self::CurveRenderer,curve::ParametricCurveAlgebra)
    println("Synced Curve!")
end

# ! Must have
function syncUpload!(self::CurveRenderer)
    upload!(self._buffer,1,self._coords,GL_DYNAMIC_DRAW)
end

# ! Must have
function draw!(self::CurveRenderer,vp,selectedID,pickedID,cam,shrd)
    vp,v,p = getMat(cam,shrd._width,shrd._height)
    
    activate(self._shader)
    setUniform!(self._shader,"VP",vp)
    draw(self._buffer,GL_LINE_STRIP)
end

# ! Must have
function destroy!(self::CurveRenderer)
    destroy!(self._shader)
    destroy!(self._buffer)
end

# ! Must have
function Plan2Renderer(self::OpenGLData,plan::ParametricCurvePlan)
    return SingleRendererTactic(self,CurveRenderer)
end