# ? ---------------------------------
# ! ParametricCurvePlan
# ? ---------------------------------

const CURVE_SOLID::UInt8    = 1
const CURVE_DASHED::UInt8   = 2
const CURVE_DOTTED::UInt8   = 3
const CURVE_WAVE::UInt8     = 4
const CURVE_DASH_DOT::UInt8 = 5
const CURVE_ARROW::UInt8    = 6
const _CURVE_COUNT::UInt8   = 6

mutable struct ParametricCurvePlan <: RenderedPlanDNA
    _plan::RenderedPlan

    _tStart::Float64
    _tEnd::Float64
    _tNum::Int
    _color::Vec3F
    _type::UInt32
    
    function ParametricCurvePlan(callback::Function,plans::Vector{T},tStart,tEnd,tNum,color,type) where {T<:PlanDNA}

        r = Float32(color[1])
        g = Float32(color[2])
        b = Float32(color[3])

        new(RenderedPlan(callback,plans),tStart,tEnd,tNum,Vec3F(r,g,b),type)
    end
end

_RenderedPlan_(self::ParametricCurvePlan)::RenderedPlan = return self._plan
Base.string(self::ParametricCurvePlan)::String = return "Curve"


# ? ---------------------------------
# ! ParametricCurveDependent
# ? ---------------------------------

mutable struct ParametricCurveDependent <: RenderedDependentDNA
    _renderedDependent::RenderedDependent
    
    _tStart::Float64
    _tEnd::Float64
    _tNum::Int
    _color::Vec3F
    _type::UInt32
    _typeLast::UInt32

    _ref::Int
    _tValues::Union{SubArray{Vec3F},Nothing}

    

    function ParametricCurveDependent(plan::ParametricCurvePlan)
        a = RenderedDependent(plan)
        tStart = plan._tStart
        tEnd = plan._tEnd
        tNum = plan._tNum
        color = plan._color
        type = plan._type

        new(a,tStart,tEnd,tNum,color,type,type,0,nothing)
    end
end

function Base.iterate(self::ParametricCurveDependent, index::Integer = 1)
    if ((index >= 1) && (index <= length(self)))
        return (self[index], (index + 1))
    else
        return nothing
    end
end

function Base.getindex(self::ParametricCurveDependent, index::Integer)::Union{Nothing, LineSegment}
    if ((index >= 1) && (index <= length(self) - 1))
        return LineSegment(self._tValues[index], self._tValues[index + 1])
    else
        return nothing 
    end
end

Base.length(self::ParametricCurveDependent) = self._tNum

# ! Must have
function Plan2Dependent(plan::ParametricCurvePlan)::ParametricCurveDependent
    return ParametricCurveDependent(plan)
end

Base.string(self::ParametricCurveDependent)::String =  return "ParametricCurve: $(self._startIndex) - $(self._endIndex) - $(self._tNum)"
_RenderedDependent_(self::ParametricCurveDependent)::RenderedDependent = return self._renderedDependent

function evalCallback(self::ParametricCurveDependent,t,index)
    return _Dependent_(self)._callback(t,_Dependent_(self)._graphParents...)
end

dpCallbackReturn(self::ParametricCurveDependent,t,index,v::Tuple)  = ((x,y,z) = v ; self._tValues[index] = Vec3F(x,y,z))
dpCallbackReturn(self::ParametricCurveDependent,t,index,::Nothing) = self._tValues[index] = Vec3FNan

function runCallbacks(self::ParametricCurveDependent)
    for index in 1:self._tNum
        t1 = Float64(index - 1)
        t2 = Float64(self._tNum - 1)
        t = (t1 / t2) * (self._tEnd - self._tStart) + self._tStart
        dpEvalCallback(self,t,index)
    end
end


# ? ---------------------------------
# ! CurveRenderer
# ? ---------------------------------

mutable struct CurveRenderer <: RendererDNA{ParametricCurveDependent}
    _renderer::Renderer{ParametricCurveDependent}

    _shader::ShaderProgram
    _shaders::Vector{ShaderProgram}
    _buffer::TypedBufferArray

    _ranges::Vector{Tuple{Int,Int,Int}}
    _drawRanges::Vector{Tuple{Int,Int}}

    _coords::Vector{Vec3F}
    _widths::Vector{Float32}
    _colors::Vector{Float32}
    _needMaintance::Bool

    function CurveRenderer(context::OpenGLData)
        
        renderer = Renderer{ParametricCurveDependent}(context)

        shaders = Vector{ShaderProgram}()
        vert = sp("curve/curve.vert")
        geom = sp("curve/curve.geom")
        uniforms = ["VP","Eye","W_H_NEAR_FAR","At"]
        push!(shaders,ShaderProgram(vert,geom,sp("curve/curve_solid.frag"),   uniforms))
        push!(shaders,ShaderProgram(vert,geom,sp("curve/curve_dashed.frag"),  uniforms))
        push!(shaders,ShaderProgram(vert,geom,sp("curve/curve_dotted.frag"),  uniforms))
        push!(shaders,ShaderProgram(vert,geom,sp("curve/curve_wave.frag"),    uniforms))
        push!(shaders,ShaderProgram(vert,geom,sp("curve/curve_dash_dot.frag"),uniforms))
        push!(shaders,ShaderProgram(vert,geom,sp("curve/curve_arrow.frag"),   uniforms))

        shader = ShaderProgram(sp("curve/curve.vert"),sp("curve/curve.geom"),sp("curve/curve_solid.frag"),["VP","Eye","W_H_NEAR_FAR","At"])
        buffer = TypedBufferArray{Tuple{Vec3F,Float32,Float32,Float32}}()

        ranges = Vector{Tuple{Int,Int,Int}}()
        drawRanges = fill((0,0),_CURVE_COUNT)

        coords = Vector{Vec3F}()
        widths = Vector{Float32}()
        colors = Vector{Float32}()
        push!(coords, Vec3FNan)
        push!(widths, 0.0f0)
        push!(colors, 0.0f0)

        needMaintance = false

        new(
            renderer,
            shader,
            shaders,
            buffer,
            ranges,
            drawRanges,
            coords,
            widths,
            colors,
            needMaintance)
    end
end

function _maintainCurveRenderer!(self::CurveRenderer)
    fill!(self._drawRanges,(typemax(Int),typemin(Int)))
    range_groups = [Vector{Int}() for _ in 1:_CURVE_COUNT]
    for index = 1:length(self._ranges)
        push!(range_groups[self._ranges[index][3]],index)
    end
    ranges = Vector{Tuple{Int,Int,Int}}()

    coords = Vector{Vec3F}()
    widths = Vector{Float32}()
    colors = Vector{Float32}()
    push!(coords, Vec3FNan)
    push!(widths, 0.0f0)
    push!(colors, 0x0)

    for group in range_groups
        for range_ind in group
            (first, last, type) = self._ranges[range_ind]
            push!(ranges, (length(coords)+1,length(coords)+last-first,type))
            append!(coords, self._coords[first:last])
            append!(widths, self._widths[first:last])
            append!(colors, self._colors[first:last])
            
            push!(coords, Vec3FNan)
            push!(widths, 0.0f0)
            push!(colors, 0x0)

            (min_ind,max_ind) = self._drawRanges[type]
            self._drawRanges[type] = (min(min_ind,first-1),max(max_ind,last+1))
        end
    end
    self._coords = coords
    self._widths = widths
    self._colors = colors
    self._needMaintance = false

    upload!(self._buffer,1,self._coords,GL_DYNAMIC_DRAW)
    upload!(self._buffer,2,self._widths,GL_STATIC_DRAW)
    upload!(self._buffer,3,self._colors,GL_STATIC_DRAW)
end

_Renderer_(self::CurveRenderer) = return self._renderer
Base.string(self::CurveRenderer) = return "CurveRenderer[$(length(self._coords))]"

function pack_color(color::Vec3F, reversed::Bool)::Float32
    color = Vec4F(color * 255.0f0, reversed ? 255.0f0 : 0.0f0)
    #round(clamp(color, 0.0, 255.0)) TODO clamp

    r = UInt32(round(color.x))
    g = UInt32(round(color.y))
    b = UInt32(round(color.z))
    a = UInt32(round(color.w))
    result = (a << 24) | (b << 16) | (g << 8) | r
    return reinterpret(Float32,result)
end

# ! Must have
function added!(self::CurveRenderer,curve::ParametricCurveDependent)
    push!(self._ranges, (length(self._coords)+1,length(self._coords)+curve._tNum,curve._type))
    curve._ref = length(self._ranges)
    packed_color = pack_color(curve._color,false)
    for _ in 1:curve._tNum
        push!(self._coords, Vec3F(0,0,0))
        push!(self._widths, 5.0f0)
        push!(self._colors, packed_color)
    end
    push!(self._coords, Vec3FNan)
    push!(self._widths, 0.0f0)
    push!(self._colors, 0x0)

    (first, last, _) = self._ranges[curve._ref]
    curve._tValues = view(self._coords, first : last)

    runCallbacks(curve)
end

setRenderedID!(renderer::CurveRenderer,dependent::ParametricCurveDependent,id) = return nothing

# ! Must have
function addedAll!(self::CurveRenderer)
    _maintainCurveRenderer!(self)
end

# ! Must have
function sync!(self::CurveRenderer,curve::ParametricCurveDependent)
    if curve._type != curve._typeLast
        self._needMaintance = true
        (first, last, _) = self._ranges[curve._ref]
        self._ranges[curve._ref] = (first, last, curve._type)
        curve._typeLast = curve._type
    end
end

# ! Must have
function syncAll!(self::CurveRenderer)
    if self._needMaintance
        _maintainCurveRenderer!(self)
    else
        upload!(self._buffer,1,self._coords,GL_DYNAMIC_DRAW)
    end
end

# ! Must have
function draw!(self::CurveRenderer,vp,selectedID,pickedID,cam,shrd)
    # ? vp,v,p = getMat(cam,shrd._width,shrd._height)
    distances = fill(NaN32, length(self._coords))
    Threads.@threads for (first,last,_) in self._ranges
        distance_sum = 0.0f0
        last_p = Vec2(NaN32,NaN32)
        for i in first:last
            p4 = vp * Vec4F(self._coords[i], 1.0f0)
            p = Vec2F(p4.x,p4.y) / p4.w
            p = p .* 0.5f0 .+ 0.5f0
            p = p .* Vec2F(shrd._width, shrd._height)

            if i != first
                distance_sum += norm(last_p - p)
            end
            distances[i] = distance_sum
            last_p = p
        end
    end
    upload!(self._buffer,4,distances,GL_DYNAMIC_DRAW)
    
    activate(self._buffer)
    glEnable(GL_BLEND)
    for type in 1:_CURVE_COUNT
        if self._drawRanges[type][1] == typemax(Int) continue end
        activate(self._shaders[type])
        setUniform!(self._shader,"VP",vp)
        setUniform!(self._shader,"Eye",cam._eye)
        setUniform!(self._shader,"At",normalize(cam._at - cam._eye))
        setUniform!(self._shader,"W_H_NEAR_FAR",Vec4F(shrd._width, shrd._height, cam._zNear, cam._zFar))
        count = self._drawRanges[type][2] - self._drawRanges[type][1] + 1
        glDrawArrays(GL_LINE_STRIP_ADJACENCY, self._drawRanges[type][1] - 1, count);
    end
    glDisable(GL_BLEND)
end

# ! Must have
function destroy!(self::CurveRenderer)
    destroy!(self._shader)
    destroy!(self._buffer)
end

# ! Must have
function Plan2Observer(self::OpenGLData,plan::ParametricCurvePlan)
    return SingleRendererTactic(self,CurveRenderer)
end

function onGraphEval(self::ParametricCurveDependent)
    renderer::CurveRenderer = GetRenderer(CurveRenderer)
    (first, last, _) = renderer._ranges[self._ref]
    self._tValues = view(renderer._coords,first : last)
    runCallbacks(self)
end