# identifiers used in generated tessellation shaders
const GPU_TESS_T_RANGE = :JG_TESS_T_RANGE
const GPU_TESS_T_RANGE_STR = string(GPU_TESS_T_RANGE)

# ? ---------------------------------
# ! ParametricCurveDependent
# ? ---------------------------------

mutable struct ParametricCurveDependent <: ParametricDependentDNA
    _parametricDependent::ParametricDependent
    
    _range::AbstractRange{Float64}
    _colors::Vector{UInt32}
    _size::Float32
    _style::UInt8

    _tValues::Vector{Vec3D} # ? Calculated value for each t

    # YELLOW Thread
    function ParametricCurveDependent(
        callback::Function,dependents::Vector{<:DependentDNA},
        range::AbstractRange{Float64},
        color::Vector{UInt32},style::UInt8,size::Float32,
        callback_ast::Union{Expr,Nothing},dependent_bindings::Union{Dict{Symbol, <:DependentDNA},Nothing})
        N = length(range)
        dependent = if callback_ast === nothing || dependent_bindings === nothing
            ParametricDependent(callback,dependents)
        else
            ParametricDependent(callback,dependents,callback_ast,dependent_bindings,N)
        end
        tValues = Vector{Vec3D}(undef,N)
        new(dependent,range,color,size,style,tValues)
    end
end

Base.string(self::ParametricCurveDependent)::String = return "ParametricCurve: $(length(self._range))"
_ParametricDependent_(self::ParametricCurveDependent)::ParametricDependent = return self._parametricDependent
_RenderedDependent_(self::ParametricCurveDependent)::RenderedDependent = return _ParametricDependent_(self)._renderedDependent

Base.eltype(dependent::ParametricCurveDependent)::DataType = Vector{Vec3D}

# YELLOW Thread
# RED Thread
function onNodeEval(self::ParametricCurveDependent)
    eval_callbacks!(self)
end

function eval_callbacks_cpu!(self::ParametricCurveDependent)
    for index in 1:length(self._range)
        evalCallbackDp(self; callbackParams = self._range[index], returnParams = (index))
    end
end

function evalCallbackDpReturn(self::ParametricCurveDependent,v,index)
    if length(v) == 3
        self._tValues[index] = Vec3D(v[1],v[2],v[3])
    else
        self._tValues[index] = Vec3D(v[1],v[2],0.0)
    end
end
evalCallbackDpReturn(self::ParametricCurveDependent,v::Tuple{Any,Any},index)     = self._tValues[index] = Vec3D(v[1],v[2],0.0)
evalCallbackDpReturn(self::ParametricCurveDependent,v::Tuple{Any,Any,Any},index) = self._tValues[index] = Vec3D(v[1],v[2],v[3])
evalCallbackDpReturn(self::ParametricCurveDependent,v::Vec3D,index)              = self._tValues[index] = v
evalCallbackDpReturn(self::ParametricCurveDependent,v::Vec3F,index)              = self._tValues[index] = Vec3D(v)
evalCallbackDpReturn(self::ParametricCurveDependent,v::Vec2D,index)              = self._tValues[index] = Vec3D(v[1],v[2],0.0)
evalCallbackDpReturn(self::ParametricCurveDependent,v::Vec2F,index)              = self._tValues[index] = Vec3D(v[1],v[2],0.0)
evalCallbackDpReturn(self::ParametricCurveDependent,v::Nothing,index)            = self._tValues[index] = Vec3DNan

# ? methods for GPU tessellation

function pre_gpu_tess!(self::ParametricCurveDependent)
    shader = _ParametricDependent_(self)._tessCompShader
    @assert shader !== nothing "GPU tessellation pipeline invoked on CPU-tessellated parametric dependent"
    @assert self._range isa StepRange || self._range isa StepRangeLen "GPU tessellation currently only supports StepRanges"


    # currently assumes uniformly spaced tessellation params (which AbstractRange-s are)
    # this minimizes required CPU -> GPU upload, but can be changed later to stream non-uniform distributions
    glUniform1ui(shader.uniforms[GPU_TESS_N_STR], GLuint(length(self._range)))
    glUniform2f(shader.uniforms[GPU_TESS_T_RANGE_STR], first(self._range), step(self._range))
end

function handle_gpu_tess_result!(self::ParametricCurveDependent)::Bool
    dep::ParametricDependent = _ParametricDependent_(self)

    @time_cpu_begin ParametricTessellation GPU DataProcessing Download
    copyto!(dep._stagingBuffer, 1, dep._posBuffer._mapped, 1, dep._sampleCount)
    @time_cpu_end ParametricTessellation GPU DataProcessing Download

    @time_cpu_begin ParametricTessellation GPU DataProcessing evalCallbackDpReturn
    for i in eachindex(dep._stagingBuffer)
        v4 = dep._stagingBuffer[i]
        v3 = Vec3D(v4.x, v4.y, v4.z)

        any(x -> isnan(x) || isinf(x), v3) && return false

        evalCallbackDpReturn(self, v3, i)
    end
    @time_cpu_end ParametricTessellation GPU DataProcessing evalCallbackDpReturn

    return true
end

function try_transpile_tess_shader(self::ParametricCurveDependent)::Union{ShaderProgram,Nothing}
    @time_cpu_begin GPUTessSetup CodeGen CurveWrapperCodeGen

    dep::ParametricDependent = _ParametricDependent_(self)
    fn_data = splitdef(dep._callbackAST)

    if isempty(get(fn_data, :args, []))
        @log "cannot transpile zero argument function as a parametric curve callback" WARN
        return nothing
    end

    t_varname = namify(fn_data[:args][1]) # first argument is the parameter (t)
    popat!(fn_data[:args], 1)

    # add code for calculating the t parameter GPU-side, assuming uniform spacing
    pushfirst!(fn_data[:body].args, :(
        $t_varname = $GPU_TESS_T_RANGE[:x] + Float32($GPU_TESS_ID) * $GPU_TESS_T_RANGE[:y]
    ))

    dep._callbackAST = combinedef(fn_data)
    @time_cpu_end GPUTessSetup CodeGen CurveWrapperCodeGen

    return try_transpile_tess_shader_base(dep._callbackAST, dep._dependentBindings, [(GPU_TESS_T_RANGE_STR, Vec2)])
end

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
# ! Curves
# ? ---------------------------------

mutable struct Curves <: RendererDNA{ParametricCurveDependent}
    _renderer::Renderer{ParametricCurveDependent}
    _renderers::PrimitiveRenderers
    _refs::Vector{UInt32}

    # GREEN Thread
    function Curves(context::OpenGLData)
        renderer = Renderer{ParametricCurveDependent}(context)
        refs = Vector{UInt32}()
        new(renderer, context._renderers, refs)
    end
end

_Renderer_(self::Curves) = return self._renderer
Base.string(self::Curves) = return "Curves[$(length(self._coords))]"

# GREEN Thread
function added!(self::Curves,curve::ParametricCurveDependent)
    aID = UInt32(getGraphID(curve) + ID_LOWER_BOUND)
    push!(self._refs,
        add!(self._renderers.line,
            curve._tValues,
            cycle(curve._colors),
            cycle(aID),
            curve._size,
            curve._style,
        )
    )
end

# GREEN Thread
function sync!(self::Curves,curve::ParametricCurveDependent)
    ref = self._refs[getObserverID(curve)]
    update_coords!(self._renderers.line,ref,curve._tValues)
end

# GREEN Thread
function destroy!(self::Curves) end

# YELLOW Thread
Dependent2Observer(app::AppDNA,::ParametricCurveDependent) = getDependentObservers(app)[_CURVES]

# YELLOW Thread
function ParametricCurve(callback::Function,range::AbstractRange{Float64},
                dependents::Vector{<:DependentDNA}=DependentDNA[],color_style::Union{Nothing,String}=nothing;
                color="c",style="-",size=5.0f0,
                enable_gpu_tessellation::Bool=false,callback_ast::Union{Expr,Nothing}=nothing,
                dependent_bindings::Union{Dict{Symbol, <:DependentDNA},Nothing}=nothing)::ParametricCurveDependent
    if !enable_gpu_tessellation
        callback_ast = nothing
        dependent_bindings = nothing
    end 
    (c,s) = parse_line_colors_style(color_style,color,style)
    return Build!(ParametricCurveDependent(callback,dependents,range,c,s,Float32(size),callback_ast,dependent_bindings))
end

macro ParametricCurve(callback::Expr,range,args...)
    (positional_args, kw_args) = _parse_macro_arguments((:color_style,),(:color, :style, :size, :enable_gpu_tessellation), args...)
    callback = _validate_callback_expr(callback, 1)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.ParametricCurve,
                                positional_args, kw_args, (cb, deps) -> (cb, range, deps), true)
end

export ParametricCurve
export @ParametricCurve
