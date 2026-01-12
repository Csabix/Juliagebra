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

export CURVE_SOLID, CURVE_DASHED, CURVE_DOTTED, 
        CURVE_WAVE, CURVE_DASH_DOT, CURVE_ARROW

mutable struct ParametricCurvePlan <: RenderedPlanDNA
    _plan::RenderedPlan

    _range::AbstractRange{Float64}
    _colors::Vector{Vec3F}
    _type::UInt8
    _reversed::UInt8
    _width::Float32
    
    function ParametricCurvePlan(callback::Function, plans::Vector{T},
                                 range::AbstractRange{Float64},
                                 color::Tuple{Real,Real,Real},
                                 type::UInt8,reversed::UInt8,width::Real) where {T<:PlanDNA}
        
        ParametricCurvePlan(callback,plans,range,[color],type,reversed,width)
    end

    function ParametricCurvePlan(callback::Function,plans::Vector{T},
                                 range::AbstractRange{Float64},
                                 color::Vector{U},
                                 type::UInt8,reversed::UInt8,width::Real) where {T<:PlanDNA, U<:Tuple{Real,Real,Real}}
        
        colors = [Vec3F(c[1],c[2],c[3]) for c in color]
        width = clamp(width,1.0,10.0)
        new(RenderedPlan(callback,plans),range,colors,type,reversed,width)
    end
end

_RenderedPlan_(self::ParametricCurvePlan)::RenderedPlan = return self._plan
Base.string(self::ParametricCurvePlan)::String = return "Curve"


# ? ---------------------------------
# ! ParametricCurveDependent
# ? ---------------------------------

mutable struct ParametricCurveDependent <: RenderedDependentDNA
    _renderedDependent::RenderedDependent
    
    _range::AbstractRange{Float64}
    _colors::Vector{Vec3F}
    _width::Float32
    _type::UInt8
    _typeLast::UInt8
    _reversed::UInt8

    _ref::Int
    _tValues::Union{SubArray{Vec3F},Nothing}

    function ParametricCurveDependent(plan::ParametricCurvePlan)
        a = RenderedDependent(plan)
        range = plan._range
        colors = plan._colors
        width = plan._width
        type = plan._type
        reversed = plan._reversed

        new(a,range,colors,width,type,type,reversed,0,nothing)
    end
end

# ! Must have
function Plan2Dependent(plan::ParametricCurvePlan)::ParametricCurveDependent
    return ParametricCurveDependent(plan)
end

Base.string(self::ParametricCurveDependent)::String =  return "ParametricCurve: $(length(self._range))"
_RenderedDependent_(self::ParametricCurveDependent)::RenderedDependent = return self._renderedDependent

function runCallbacks(self::ParametricCurveDependent)
    for index in 1:length(self._range)
        evalCallbackDp(self; callbackParams = self._range[index], returnParams = (index))
    end
end

function onNodeEval(self::ParametricCurveDependent)
    renderer::CurveRenderer = getObserver(self)
    (first, last, _) = renderer._ranges[self._ref]
    self._tValues = view(renderer._coords,first:last)
    runCallbacks(self)
end

evalCallbackDpReturn(self::ParametricCurveDependent,v,index) = ((x,y,z) = v ; self._tValues[index] = Vec3F(x,y,z))
evalCallbackDpReturn(self::ParametricCurveDependent,v::Vec3D,index) = self._tValues[index] = Vec3F(v)
evalCallbackDpReturn(self::ParametricCurveDependent,v::Vec3F,index) = self._tValues[index] = v
evalCallbackDpReturn(self::ParametricCurveDependent,v::Nothing,index) = self._tValues[index] = Vec3FNan

# ? For Intersectable ParametricCurves

struct PSegmentsOfCurve <: PSegmentsOf
    _curve::ParametricCurveDependent
end
PrimitivesOf(self::ParametricCurveDependent) = return PSegmentsOfCurve(self)

Base.length(self::PSegmentsOfCurve) = (max(length(self._curve._range) - 1,0))

function Base.getindex(self::PSegmentsOfCurve, index::Integer)::Union{Nothing, PSegment}
    if ((1 <= index) && (index <= length(self)))
        return PSegment(self._curve._tValues[index], self._curve._tValues[index + 1])
    else
        return nothing 
    end
end

function Base.iterate(self::PSegmentsOfCurve, index::Integer = 1)
    if ((1 <= index) && (index <= length(self)))
        return (self[index], (index + 1))
    else
        return nothing
    end
end


# ? ---------------------------------
# ! CurveRenderer
# ? ---------------------------------

mutable struct CurveRenderer <: RendererDNA{ParametricCurveDependent}
    _renderer::Renderer{ParametricCurveDependent}

    _shaders::Vector{ShaderProgram}
    _buffer::TypedBufferArray

    _ranges::Vector{Tuple{Int,Int,Int}}
    _drawRanges::Vector{Tuple{Int,Int}}

    _coords::Vector{Vec3F}
    _widths::Vector{Float32}
    _colors::Vector{Float32}
    _distances::Vector{Float32} # to avoid memory allocations
    _needMaintance::Bool

    function CurveRenderer(context::OpenGLData)
        
        renderer = Renderer{ParametricCurveDependent}(context)

        shaders = Vector{ShaderProgram}()
        vert = sp("curve/curve.vert")
        geom = sp("curve/curve.geom")
        uniforms = ["VP","Eye","W_H_NEAR_FAR","lightDirCam","lightDirSide"]
        push!(shaders,ShaderProgram(vert,geom,sp("curve/curve_solid.frag"),   uniforms))
        push!(shaders,ShaderProgram(vert,geom,sp("curve/curve_dashed.frag"),  uniforms))
        push!(shaders,ShaderProgram(vert,geom,sp("curve/curve_dotted.frag"),  uniforms))
        push!(shaders,ShaderProgram(vert,geom,sp("curve/curve_wave.frag"),    uniforms))
        push!(shaders,ShaderProgram(vert,geom,sp("curve/curve_dash_dot.frag"),uniforms))
        push!(shaders,ShaderProgram(vert,geom,sp("curve/curve_arrow.frag"),   uniforms))

        buffer = TypedBufferArray{Tuple{Vec3F,Float32,Float32,Float32}}()

        ranges = Vector{Tuple{Int,Int,Int}}()
        drawRanges = fill((0,0),_CURVE_COUNT)

        coords = [Vec3FNan]
        widths = [0.0f0]
        colors = [0.0f0]
        distances = Vector{Float32}(undef,1)

        needMaintance = false
        new(
            renderer,
            shaders,
            buffer,
            ranges,
            drawRanges,
            coords,
            widths,
            colors,
            distances,
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
            (min_ind,max_ind) = self._drawRanges[type]
            self._ranges[range_ind] = (length(coords)+1,length(coords)+last-first+1,type)
            self._drawRanges[type] = (min(min_ind,length(coords)-1),max(max_ind,length(coords)+last-first+2))
            
            append!(coords, self._coords[first:last])
            append!(widths, self._widths[first:last])
            append!(colors, self._colors[first:last])
            
            push!(coords, Vec3FNan)
            push!(widths, 0.0f0)
            push!(colors, 0x0)
        end
    end
    self._coords = coords
    self._widths = widths
    self._colors = colors
    self._distances = Vector{Float32}(undef,length(coords))
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
    push!(self._ranges, (length(self._coords)+1,length(self._coords)+length(curve._range),curve._type))
    curve._ref = length(self._ranges)
    color_count = length(curve._colors)
    packed_colors = [pack_color(color,curve._reversed != 0x0) for color in curve._colors]
    current_color = 1
    for _ in 1:length(curve._range)
        push!(self._coords, Vec3F(0,0,0))
        push!(self._widths, curve._width)
        push!(self._colors, packed_colors[current_color])
        current_color = mod1(current_color + 1, color_count)
    end
    push!(self._coords, Vec3FNan)
    push!(self._widths, 0.0f0)
    push!(self._colors, 0x0000000)

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
    @time_cpu_begin Dependent Curve
    if self._needMaintance
        _maintainCurveRenderer!(self)
    else
        upload!(self._buffer,1,self._coords,GL_DYNAMIC_DRAW)
    end
    @time_cpu_end Dependent Curve
end

# ! Must have
function draw!(self::CurveRenderer,vp,selectedID,pickedID,cam,shrd)
    @time_cpu_begin Dependent Curve Distances
    Threads.@threads for (first,last,_) in self._ranges
        wh = Vec2F(shrd._width,shrd._height)
        distance_sum = 0.0f0
        for i in first:(last-1)
            a = vp * Vec4F(self._coords[i], 1.0f0)
            b = vp * Vec4F(self._coords[i+1], 1.0f0)
            if a.z + a.w < 0.0 && b.z + b.w < 0.0f0 continue end
            t0 = a.z + a.w;
            t1 = b.z + b.w;
            if t0 < 0.0
                tt = t0 / (t0 - t1)
                a = @. a * (1 - tt) + b * tt
            elseif t1 < 0.0
                tt = t1 / (t1 - t0)
                b = @. b * (1 - tt) + a * tt
            end
            a2 = Vec2F(a.x,a.y) / a.w
            a2 = a2 .* 0.5f0 .+ 0.5f0
            a2 = a2 .* wh

            b2 = Vec2F(b.x,b.y) / b.w
            b2 = b2 .* 0.5f0 .+ 0.5f0
            b2 = b2 .* wh

            self._distances[i] = distance_sum
            distance_sum += norm(a2 - b2)
        end
        self._distances[last] = distance_sum
    end
    @time_cpu_end Dependent Curve Distances

    upload!(self._buffer,4,self._distances,GL_DYNAMIC_DRAW)
    (cam_light, side_light) = get_lights(cam)
    activate(self._buffer)
    glEnable(GL_BLEND)
    @time_gpu_begin Dependent Curve
    for type in 1:_CURVE_COUNT
        (first,last) = self._drawRanges[type]
        if first == typemax(Int) continue end
        activate(self._shaders[type])
        setUniform!(self._shaders[type],"VP",vp)
        setUniform!(self._shaders[type],"Eye",cam._eye)
        setUniform!(self._shaders[type],"lightDirCam", cam_light)
        setUniform!(self._shaders[type],"lightDirSide",side_light)
        setUniform!(self._shaders[type],"W_H_NEAR_FAR",Vec4F(shrd._width, shrd._height, cam._zNear, cam._zFar))
        glDrawArrays(GL_LINE_STRIP_ADJACENCY, first, last-first);
    end
    @time_gpu_end Dependent Curve
    glDisable(GL_BLEND)
end

# ! Must have
function destroy!(self::CurveRenderer)
    foreach(destroy!, self._shaders)
    destroy!(self._buffer)
end

# ! Must have
function Plan2Observer(self::OpenGLData,plan::ParametricCurvePlan)
    return SingleRendererTactic(self,CurveRenderer)
end