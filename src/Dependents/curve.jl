
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

    _ref::Int # ? Reference index for CurveRenderer
    _tValues::Vector{Vec3D} # ? Calculated value for each t

    # YELLOW Thread
    function ParametricCurveDependent(
        callback::Function,dependents::Vector{<:DependentDNA},
        range::AbstractRange{Float64},
        colors::Vector{<:Tuple{Real,Real,Real}},
        type::UInt8,reversed::UInt8,width::Real
        )

        color = [Vec3F(c[1],c[2],c[3]) for c in colors]
        rd = RenderedDependent(callback,dependents)
        tValues = Vector{Vec3D}(undef,length(range))
        new(rd,range,color,width,type,type,reversed,0,tValues)
    end

    # YELLOW Thread
    function ParametricCurveDependent(
        callback::Function,dependents::Vector{<:DependentDNA},
        range::AbstractRange{Float64},
        color::Tuple{Real,Real,Real},
        type::UInt8,reversed::UInt8,width::Real
        )

        rd = RenderedDependent(callback,dependents)
        tValues = Vector{Vec3D}(undef,length(range))
        new(rd,range,[color],width,type,type,reversed,0,tValues)
    end
end

Base.string(self::ParametricCurveDependent)::String =  return "ParametricCurve: $(length(self._range))"
_RenderedDependent_(self::ParametricCurveDependent)::RenderedDependent = return self._renderedDependent

# YELLOW Thread
# RED Thread
function onNodeEval(self::ParametricCurveDependent)
    for index in 1:length(self._range)
        evalCallbackDp(self; callbackParams = self._range[index], returnParams = (index))
    end
end

evalCallbackDpReturn(self::ParametricCurveDependent,v,index)          = ((x,y,z) = v ; self._tValues[index] = Vec3D(x,y,z))
evalCallbackDpReturn(self::ParametricCurveDependent,v::Vec3D,index)   = self._tValues[index] = v
evalCallbackDpReturn(self::ParametricCurveDependent,v::Vec3F,index)   = self._tValues[index] = Vec3D(v)
evalCallbackDpReturn(self::ParametricCurveDependent,v::Nothing,index) = self._tValues[index] = Vec3DNan

# ? For Intersectable ParametricCurves.

struct PSegmentsOfCurve <: PrimitivesOf{PSegment}
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
    _emptyVAO::VertexArray

    _shader_predraw::ShaderProgram
    _shaders_id::Vector{ShaderProgram}
    _shaders_opaque::Vector{ShaderProgram}
    _shaders_behind_opaque::Vector{ShaderProgram}
    _shaders_transparent::Vector{ShaderProgram}

    _ranges::Vector{Tuple{Int,Int,Int}}
    _drawRanges::Vector{Tuple{Int,Int}}

    _coords::Vector{Vec3D}
    _widths::Dict{Int,Float32}
    _colors::Vector{Float32}

    _distances::Vector{Float32} # to avoid memory allocations
    _position_width::Vector{Vec4F}
    _needMaintance::Bool

    _distance_buffer_in::MappedBuffer{Float32}
    _color_type_buffer_in::Buffer{Float32}
    _position_width_buffer_in::MappedBuffer{Vec4F}

    _position_distance_buffer_out::Buffer{Vec4F}
    _color_buffer_out::Buffer{UVec2}
    _light_buffer_out::Buffer{Vec4F}
    _sdf_buffer_out::Buffer{Vec4F}

    # GREEN Thread
    function CurveRenderer(context::OpenGLData)
        renderer = Renderer{ParametricCurveDependent}(context)

        shader_predraw = ShaderProgram(["curve/curve_vertex.comp"],["VP","WH","Eye","lightDirCam","lightDirSide"])

        types = ["solid","dashed","dotted","wave","dash_dot","arrow"]

        shaders_id = Vector{ShaderProgram}()
        for type in types push!(shaders_id,ShaderProgram(["curve/id/curve.vert","curve/id/curve_$type.frag"])) end

        shaders_opaque = Vector{ShaderProgram}()
        for type in types push!(shaders_opaque,ShaderProgram(["curve/opaque/curve.vert","curve/opaque/curve_$type.frag"])) end

        shaders_behind_opaque = Vector{ShaderProgram}()
        for type in types push!(shaders_behind_opaque,ShaderProgram(["curve/behind_opaque/curve.vert","curve/behind_opaque/curve_$type.frag"])) end

        shaders_transparent = Vector{ShaderProgram}()
        for type in types push!(shaders_transparent,ShaderProgram(["curve/opaque/curve.vert","curve/transparent/curve_$type.frag"])) end

        ranges = Vector{Tuple{Int,Int,Int}}()
        drawRanges = fill((0,0),_CURVE_COUNT)

        coords = [Vec3DNan]
        widths = Dict{Int,Float32}()
        colors = [0.0f0]
        distances = Vector{Float32}()
        position_width = Vector{Vec4F}()
        
        needMaintance = false
        new(renderer,
            VertexArray(),
            shader_predraw,shaders_id,shaders_opaque,shaders_behind_opaque,shaders_transparent,
            ranges,drawRanges,
            coords,widths,colors,
            distances,position_width,needMaintance,
            MappedBuffer{Float32}(),Buffer{Float32}(),MappedBuffer{Vec4F}(),
            Buffer{Vec4F}(),Buffer{UVec2}(),Buffer{Vec4F}(),Buffer{Vec4F}())
    end
end

@inbounds function _upload_positon_width(self::CurveRenderer)
    @time_cpu_begin Dependent Curve UPLOAD_POSITION
    Threads.@threads for (first,last,_) in self._ranges
        width = self._widths[first]
        for i = first:last
            p = self._coords[i]
            self._position_width[i] = Vec4F(p.x,p.y,p.z,width)
        end
    end
    wait(self._position_width_buffer_in)
    copyto!(self._position_width_buffer_in,self._position_width)
    @time_cpu_end Dependent Curve UPLOAD_POSITION
end

function _maintainCurveRenderer!(self::CurveRenderer)
    fill!(self._drawRanges,(typemax(Int),typemin(Int)))
    range_groups = [Vector{Int}() for _ in 1:_CURVE_COUNT]
    for index = 1:length(self._ranges)
        push!(range_groups[self._ranges[index][3]],index)
    end

    coords = Vector{Vec3D}()
    widths = Dict{Int,Float32}()
    colors = Vector{Float32}()
    push!(coords, Vec3DNan)
    push!(colors, 0x0)

    for group in range_groups
        for range_ind in group
            (first, last, type) = self._ranges[range_ind]
            (min_ind,max_ind) = self._drawRanges[type]
            self._ranges[range_ind] = (length(coords)+1,length(coords)+last-first+1,type)
            widths[length(coords)+1] = self._widths[first]
            self._drawRanges[type] = (min(min_ind,length(coords)-1),max(max_ind,length(coords)+last-first+1))
            
            append!(coords, self._coords[first:last])
            append!(colors, self._colors[first:last])
            
            push!(coords, Vec3DNan)
            push!(colors, 0x0)
        end
    end
    self._coords = coords
    self._widths = widths
    self._colors = colors

    self._needMaintance = false

    upload!(self._color_type_buffer_in,self._colors,UInt32(0))
    _upload_positon_width(self)
end

_Renderer_(self::CurveRenderer) = return self._renderer
Base.string(self::CurveRenderer) = return "CurveRenderer[$(length(self._coords))]"

function pack_color(color::Vec3F, reversed::Bool)::Float32
    color = Vec4F(clamp.(color,0.0f0,1.0f0) * 255.0f0, reversed ? 255.0f0 : 0.0f0)

    r = UInt32(round(color.x))
    g = UInt32(round(color.y))
    b = UInt32(round(color.z))
    a = UInt32(round(color.w))
    result = (a << 24) | (b << 16) | (g << 8) | r
    return reinterpret(Float32,result)
end

# GREEN Thread
function added!(self::CurveRenderer,curve::ParametricCurveDependent)
    push!(self._ranges, (length(self._coords)+1,length(self._coords)+length(curve._range),curve._type))
    self._widths[length(self._coords)+1] = curve._width
    curve._ref = length(self._ranges)
    color_count = length(curve._colors)
    packed_colors = [pack_color(color,curve._reversed != 0x0) for color in curve._colors]
    current_color = 1
    for i in 1:length(curve._range)
        # ? copy values
        push!(self._coords, curve._tValues[i]) 
        push!(self._colors, packed_colors[current_color])
        current_color = mod1(current_color + 1, color_count)
    end
    push!(self._coords, Vec3DNan)
    push!(self._colors, 0x0000000)

    #(first, last, _) = self._ranges[curve._ref]
    #curve._tValues = view(self._coords, first : last)

    #runCallbacks(curve)
end

# GREEN Thread
function addedAll!(self::CurveRenderer)
    self._distances = Vector{Float32}(undef,length(self._coords))
    self._position_width = fill(Vec4FNan, length(self._coords))
    
    reserve!(self._distance_buffer_in,length(self._coords),GL_DYNAMIC_STORAGE_BIT)
    reserve!(self._position_width_buffer_in,length(self._coords),GL_DYNAMIC_STORAGE_BIT)

    reserve!(self._position_distance_buffer_out,5*length(self._coords),UInt32(0))
    reserve!(self._color_buffer_out,length(self._coords),UInt32(0))
    reserve!(self._light_buffer_out,length(self._coords),UInt32(0))
    reserve!(self._sdf_buffer_out,5*length(self._coords),UInt32(0))

    _maintainCurveRenderer!(self)
end

# GREEN Thread
function sync!(self::CurveRenderer,curve::ParametricCurveDependent)
    # ? copy values
    (first, last, _) = self._ranges[curve._ref]
    self._coords[first:last] = curve._tValues
    
    if curve._type != curve._typeLast
        self._needMaintance = true
        self._ranges[curve._ref] = (first, last, curve._type)
        curve._typeLast = curve._type
    end
end

# GREEN Thread
function syncAll!(self::CurveRenderer)
    @time_cpu_begin Dependent Curve
    if self._needMaintance
        _maintainCurveRenderer!(self)
    else
        _upload_positon_width(self)
    end
    @time_cpu_end Dependent Curve
end

function _calc_distances!(self::CurveRenderer,vp::Mat4,wh::Vec2F)
    @time_cpu_begin Dependent Curve Distances
    Threads.@threads for (first,last,_) in self._ranges
        distance_sum = 0.0f0
        for i in first:(last-1)
            a = vp * Vec4F(Vec3F(self._coords[i]), 1.0f0)
            b = vp * Vec4F(Vec3F(self._coords[i+1]), 1.0f0)
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
            distance_sum = !isnan(norm(a2 - b2)) ? distance_sum + norm(a2 - b2) : 0
        end
        self._distances[last] = distance_sum
    end
    @time_cpu_end Dependent Curve Distances
    wait(self._distance_buffer_in)
    copyto!(self._distance_buffer_in, self._distances)
end

function pre_draw!(self::CurveRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    _calc_distances!(self,vp,Vec2F(shrd._width,shrd._height))

    bind_ssbo(self._distance_buffer_in,0)
    bind_ssbo(self._color_type_buffer_in,1)
    bind_ssbo(self._position_width_buffer_in,2)
    bind_ssbo(self._position_distance_buffer_out,3)
    bind_ssbo(self._color_buffer_out,4)
    bind_ssbo(self._light_buffer_out,5)
    bind_ssbo(self._sdf_buffer_out,6)

    (cam_light, side_light) = get_lights(cam)
    activate(self._shader_predraw)
    uniform(self._shader_predraw,"VP",vp)
    uniform(self._shader_predraw,"WH",Vec2F(shrd._width, shrd._height))
    uniform(self._shader_predraw,"Eye",cam._eye)
    uniform(self._shader_predraw,"lightDirCam", cam_light)
    uniform(self._shader_predraw,"lightDirSide",side_light)
    @time_gpu_begin Dependent Curve PRE_DRAW_PASS
    glDispatchCompute(cld(length(self._coords),32),1,1);
    @time_gpu_end Dependent Curve PRE_DRAW_PASS 
    glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT)
    lock(self._distance_buffer_in)
    lock(self._position_width_buffer_in)
    return nothing
end

function id_pass!(self::CurveRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    activate(self._emptyVAO)
    bind_ssbo(self._position_distance_buffer_out,0)
    bind_ssbo(self._sdf_buffer_out,1)

    baseInstance = 0
    @time_gpu_begin Dependent Curve ID_PASS
    for type in 1:_CURVE_COUNT
        (first,last) = self._drawRanges[type]
        if first == typemax(Int) continue end
        activate(self._shaders_id[type])
        glDrawArraysInstancedBaseInstance(GL_TRIANGLE_STRIP, 0, 5, last-first-2, baseInstance)
        baseInstance += last-first
    end
    @time_gpu_end Dependent Curve ID_PASS
end

function opaque_pass!(self::CurveRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    activate(self._emptyVAO)
    bind_ssbo(self._position_distance_buffer_out,0)
    bind_ssbo(self._color_buffer_out,1)
    bind_ssbo(self._light_buffer_out,2)
    bind_ssbo(self._sdf_buffer_out,3)

    baseInstance = 0
    glEnable(GL_BLEND)
    @time_gpu_begin Dependent Curve OPAQUE_PASS
    for type in 1:_CURVE_COUNT
        (first,last) = self._drawRanges[type]
        if first == typemax(Int) continue end
        activate(self._shaders_opaque[type])
        glDrawArraysInstancedBaseInstance(GL_TRIANGLE_STRIP, 0, 5, last-first-2, baseInstance)
        baseInstance += last-first
    end
    @time_gpu_end Dependent Curve OPAQUE_PASS
    glDisable(GL_BLEND)
end

is_occluder(self::CurveRenderer)::Bool = false

function behind_opaque_pass!(self::CurveRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    activate(self._emptyVAO)
    bind_ssbo(self._position_distance_buffer_out,0)
    bind_ssbo(self._color_buffer_out,1)
    bind_ssbo(self._sdf_buffer_out,2)

    baseInstance = 0
    @time_gpu_begin Dependent Curve BEHIND_OPAQUE_PASS
    for type in 1:_CURVE_COUNT
        (first,last) = self._drawRanges[type]
        if first == typemax(Int) continue end
        activate(self._shaders_behind_opaque[type])
        glDrawArraysInstancedBaseInstance(GL_TRIANGLE_STRIP, 0, 5, last-first-2, baseInstance)
        baseInstance += last-first
    end
    @time_gpu_end Dependent Curve BEHIND_OPAQUE_PASS
end

function transparent_pass!(self::CurveRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    activate(self._emptyVAO)
    bind_ssbo(self._position_distance_buffer_out,0)
    bind_ssbo(self._color_buffer_out,1)
    bind_ssbo(self._light_buffer_out,2)
    bind_ssbo(self._sdf_buffer_out,3)

    baseInstance = 0
    glEnable(GL_BLEND)
    @time_gpu_begin Dependent Curve TRANSPARENT_PASS
    for type in 1:_CURVE_COUNT
        (first,last) = self._drawRanges[type]
        if first == typemax(Int) continue end
        activate(self._shaders_transparent[type])
        glDrawArraysInstancedBaseInstance(GL_TRIANGLE_STRIP, 0, 5, last-first-2, baseInstance)
        baseInstance += last-first
    end
    @time_gpu_end Dependent Curve TRANSPARENT_PASS
end


# ! Must have
function destroy!(self::CurveRenderer)
    destroy!(self._emptyVAO)
    destroy!(self._shader_predraw)
    destroy!.(self._shaders_id)
    destroy!.(self._shaders_opaque)
    destroy!.(self._shaders_behind_opaque)
    destroy!.(self._shaders_transparent)

    destroy!(self._distance_buffer_in)
    destroy!(self._color_type_buffer_in)
    destroy!(self._position_width_buffer_in)
    destroy!(self._position_distance_buffer_out)
    destroy!(self._color_buffer_out)
    destroy!(self._light_buffer_out)
    destroy!(self._sdf_buffer_out)
end

# YELLOW Thread
Dependent2Observer(app::AppDNA,::ParametricCurveDependent)::CurveRenderer = getOpenGL(app)._renderers[3]

# ? ---------------------------------
# ! ParametricCurve
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

# YELLOW Thread
"""
    ParametricCurve(callback, range, [dependents]; kwargs...) -> ParametricCurvePlan

Construct a plan for a parametric curve defined by a generator function over a specific interval.

# Arguments
- `callback::Function`: A function (typically `t,dependents... -> Point`) that defines the curve's path.
- `range::AbstractRange{Float64}`: The interval and step size over which the `callback` is evaluated.
- `dependents::DependentsT`: A collection of `PlanDNA` objects that this curve depends on. Defaults to an empty vector.

# Keyword Arguments
- `color=(0.6, 0.6, 0.9)`: The RGB tuple or array of tuples defining the curve's color.
- `width=5.0f0`: The line thickness.
- `type=CURVE_SOLID`: The visual style of the curve (e.g., solid, dashed).
- `reversed=false`: Whether to flip the line pattern.

# Returns
- `ParametricCurvePlan`: A `PlanDNA` for further use in dependencies.

# Example
App();

curve = ParametricCurve(t -> (cos(t), sin(t), 0.0), 0:0.1:2π; color=(1, 0, 0));

play!();
"""
ParametricCurve(callback::Function,range::AbstractRange{Float64},dependents::Vector{<:DependentDNA}=Vector{DependentDNA}();
                color=(0.6,0.6,0.9),width=5.0f0,type=CURVE_SOLID,reversed=false)::ParametricCurveDependent =
return build!(ParametricCurveDependent(callback,dependents,range,color,type,reversed ? 0x1 : 0x0,width))

macro ParametricCurve(callback::Expr,range,kw_args...)
    parsed_kw_args = _parse_macro_kw_args([:color, :width, :type, :reversed], kw_args...)
    callback = _validate_callback_expr(callback, 1)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.ParametricCurve, (cb, deps) -> (cb, range, deps); parsed_kw_args...)
end

export ParametricCurve
export @ParametricCurve