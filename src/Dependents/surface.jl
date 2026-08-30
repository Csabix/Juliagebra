# uniform identifiers used in code gen / upload
const GPU_TESS_UV_GRID_SIZE = :JG_TESS_UV_GRID_SIZE
const GPU_TESS_UV_GRID_SIZE_STR = string(GPU_TESS_UV_GRID_SIZE)
const GPU_TESS_UV_RANGE = :JG_TESS_UV_RANGE
const GPU_TESS_UV_RANGE_STR = string(GPU_TESS_UV_RANGE)

# ? ---------------------------------
# ! ParametricSurfaceDependent
# ? ---------------------------------

mutable struct ParametricSurfaceDependent{Range<:AbstractRange} <: ParametricDependentDNA
    _parametricDependent::ParametricDependent
    
    _uvValues::FlatMatrix{Vec3D}
    _uvNormals::FlatMatrix{Vec3D}
    _layer::Int

    _uRange::Range
    _vRange::Range

    _color::UInt32
    _isInfinite::Bool

    _normalsBuffer::Union{MappedBuffer{Vec4},Nothing}

    # YELLOW Thread
    function ParametricSurfaceDependent(
        callback::Function,dependents::Vector{<:DependentDNA},
        uRange::Range,
        vRange::Range,
        color::UInt32,
        callback_ast::Union{Expr,Nothing},
        dependent_bindings::Union{Dict{Symbol, <:DependentDNA},Nothing};
        isInfinite::Bool = false
        ) where {Range<:AbstractRange}

        Nu = length(uRange)
        Nv = length(vRange)
        pd = if callback_ast !== nothing && dependent_bindings !== nothing
            ParametricDependent(callback,dependents,callback_ast,dependent_bindings,Nu*Nv)
        else
            ParametricDependent(callback,dependents,Nu*Nv)
        end
        uvValues = FlatMatrix{Vec3D}(Nu,Nv)        
        uvNormals = FlatMatrix{Vec3D}(Nu,Nv)

        new{Range}(pd,
            uvValues,
            uvNormals,
            0,
            uRange,
            vRange,
            color,
            isInfinite,
            nothing)
    end
end

_ParametricDependent_(self::ParametricSurfaceDependent)::ParametricDependent = return self._parametricDependent
_RenderedDependent_(self::ParametricSurfaceDependent)::RenderedDependent = return _ParametricDependent_(self)._renderedDependent
Base.string(self::ParametricSurfaceDependent) = return "ParametricSurface"

# surfaces always need a position buffer for normal calculation
# CPU tess: write-only (pos data is uploaded before normal calculation, but never read)
# GPU tess: read-only (pos data is read back to the CPU, but calculated on the GPU)
function pos_buffer_info(self::ParametricSurfaceDependent)::ParamDepPosBufferInfo
    is_gpu = is_gpu_tessellated(self)
    return ParamDepPosBufferInfo(true, is_gpu, !is_gpu)
end

function post_setup_parametric_dependent!(self::ParametricSurfaceDependent)
    dep::ParametricDependent = _ParametricDependent_(self)
   
    n = width(self._uvValues) * height(self._uvValues)

    Base.resize!(dep._stagingBuffer, n)
    
    self._normalsBuffer = MappedBuffer{Vec4}(; read = true, write = false)
    reserve!(self._normalsBuffer, n, 0)
end

evalCallbackDpReturn(self::ParametricSurfaceDependent,value,u,v) = self._uvValues[u,v] = Vec3D(value)
evalCallbackDpReturn(self::ParametricSurfaceDependent,value::Tuple,u,v) = self._uvValues[u,v] = Vec3D(value...)
evalCallbackDpReturn(self::ParametricSurfaceDependent,value::Vec3F,u,v) = self._uvValues[u,v] = Vec3D(value)
evalCallbackDpReturn(self::ParametricSurfaceDependent,value::Vec3D,u,v) = self._uvValues[u,v] = value
evalCallbackDpReturn(self::ParametricSurfaceDependent,::Nothing,u,v) = self._uvValues[u,v] = Vec3DNan

# YELLOW Thread
# RED Thread
function onNodeEval(self::ParametricSurfaceDependent)
    eval_callbacks!(self)

    # extra setup and dispatch required for CPU tessellated surfaces
    # before GPU normal calculation can occur
    if is_cpu_tessellated(self)
        dep = _ParametricDependent_(self)

        h = height(self._uvValues)
        w = width(self._uvValues)
        n = h * w

        # first normal calc after GPU -> CPU fallback state
        if !dep._posBuffer._write
            dep._posBuffer._write = true
            dep._posBuffer._read = false
            reserve!(dep._posBuffer, n, 0)
        end

        @time_cpu_begin ParametricTessellation GPU Dispatch UploadPositions
        i = 1
        for v in 1:h
            for u in 1:w
                dep._stagingBuffer[i] = Vec4F(self._uvValues[u, v], 0)
                i += 1
            end
        end

        copyto!(dep._posBuffer, dep._stagingBuffer)
        @time_cpu_end ParametricTessellation GPU Dispatch UploadPositions

        # may need to start the batch (benchmark-wise) if no other GPU tessellated dependents have been eval-ed yet
        try_begin_tess_batch!()

        dispatch_normals(self)
        mark_pending!(self)
    end
end

function eval_callbacks_cpu!(self::ParametricSurfaceDependent)
    for v in eachindex(self._vRange)
        for u in eachindex(self._uRange)
            uf::Float64 = self._uRange[u]
            vf::Float64 = self._vRange[v]
            
            evalCallbackDp(self;callbackParams = (uf,vf), returnParams = (u,v))
        end
    end
end

function dispatch_normals(self::ParametricSurfaceDependent)
    h = height(self._uvValues)
    w = width(self._uvValues)

    dep::ParametricDependent = _ParametricDependent_(self)

    activate(getOpenGL(implicitApp)._surface_normals)

    glUniform2i(0, GLint(width(self._uvValues)), GLint(height(self._uvValues)))

    bind_ssbo(dep._posBuffer, 0)
    bind_ssbo(self._normalsBuffer, 1)

    glDispatchCompute(div(w + 15, 16), div(h + 15, 16), 1)
end

function resolve_normals!(self::ParametricSurfaceDependent)
    dep::ParametricDependent = _ParametricDependent_(self)
    
    h = height(self._uvValues)
    w = width(self._uvValues)
    n = h * w
    
    @time_cpu_begin ParametricTessellation GPU Resolve UpdateNormals Download
    copyto!(dep._stagingBuffer, 1, self._normalsBuffer._mapped, 1, n)
    @time_cpu_end ParametricTessellation GPU Resolve UpdateNormals Download

    @time_cpu_begin ParametricTessellation GPU Resolve UpdateNormals Update
    for v in 1:h, u in 1:w
        v4 = dep._stagingBuffer[(v - 1) * w + u]
        self._uvNormals[u, v] = Vec3D(v4.x, v4.y, v4.z)
    end
    @time_cpu_end ParametricTessellation GPU Resolve UpdateNormals Update
end

# ? methods for GPU tessellation

function pre_gpu_tess!(self::ParametricSurfaceDependent)
    shader = _ParametricDependent_(self)._tessCompShader
    @assert shader !== nothing "GPU tessellation pipeline invoked on CPU-tessellated parametric dependent"
    @assert (self._uRange isa StepRange || self._uRange isa StepRangeLen) &&
            (self._vRange isa StepRange || self._vRange isa StepRangeLen) "GPU tessellation currently only supports StepRanges"

    glUniform1ui(maybe_uniform_loc(shader, GPU_TESS_N_STR), GLuint(width(self._uvValues) * height(self._uvValues)))
    glUniform2i(maybe_uniform_loc(shader, GPU_TESS_UV_GRID_SIZE_STR), GLint(height(self._uvValues)), GLint(width(self._uvValues)))
    glUniform4f(maybe_uniform_loc(shader, GPU_TESS_UV_RANGE_STR), first(self._uRange), step(self._uRange), first(self._vRange), step(self._vRange))
end

function dispatch_gpu_tess(self::ParametricSurfaceDependent)::Bool
    dispatch_gpu_tess_compute(self) || return false

    glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT)

    dispatch_normals(self)
    
    return true
end

function resolve_gpu_tess!(self::ParametricSurfaceDependent)::Bool
    dep::ParametricDependent = _ParametricDependent_(self)
    
    # ? this function is also called by CPU tessellated surfaces for normal readback
    if is_gpu_tessellated(self)
        @time_cpu_begin ParametricTessellation GPU Resolve DataProcessing Download
        copyto!(dep._stagingBuffer, 1, dep._posBuffer._mapped, 1, dep._sampleCount)
        @time_cpu_end ParametricTessellation GPU Resolve DataProcessing Download

        @time_cpu_begin ParametricTessellation GPU Resolve DataProcessing evalCallbackDpReturn
        i::Int = 1
        for v in 1:height(self._uvValues)
            for u in 1:width(self._uvValues)
                v4 = dep._stagingBuffer[i]
                v3 = Vec3F(v4.x, v4.y, v4.z)

                if any(x -> isnan(x) || isinf(x), v3)
                    @time_cpu_end ParametricTessellation GPU Resolve DataProcessing evalCallbackDpReturn
                    @log "Invalid value found in surface tessellation results" WARN
                    return false
                end

                evalCallbackDpReturn(self, v3, u, v)

                i += 1
            end
        end
        @time_cpu_end ParametricTessellation GPU Resolve DataProcessing evalCallbackDpReturn
    end

    resolve_normals!(self)

    return true
end

function try_transpile_tess_shader(self::ParametricSurfaceDependent)::Union{ShaderProgram,Nothing}
    @time_cpu_begin GPUTessSetup CodeGen SurfaceWrapperCodeGen

    dep::ParametricDependent = _ParametricDependent_(self)

    fn_data = splitdef(dep._callbackAST)

    if length(get(fn_data, :args, [])) < 2
        @log "cannot transpile function with less than two arguments as a parametric surface callback" INFO
        return nothing
    end

    u_varname = namify(fn_data[:args][1]) # first argument is the first parameter (u)
    v_varname = namify(fn_data[:args][2]) # second argument is the second parameter (v)
    deleteat!(fn_data[:args], 1:2)

    # add code for calculating the u, v parameters GPU-side
    pushfirst!(fn_data[:body].args, quote
        $u_varname = JG_TESS_UV_RANGE[:x] + (Int32(JG_TESS_ID) % JG_TESS_UV_GRID_SIZE[:y]) * JG_TESS_UV_RANGE[:y]
        $v_varname = JG_TESS_UV_RANGE[:z] + div(Int32(JG_TESS_ID), JG_TESS_UV_GRID_SIZE[:y]) * JG_TESS_UV_RANGE[:w]
    end)

    dep._callbackAST = combinedef(fn_data)
    @time_cpu_end GPUTessSetup CodeGen SurfaceWrapperCodeGen

    return try_transpile_tess_shader_base(dep._callbackAST, dep._dependentBindings, [(GPU_TESS_UV_GRID_SIZE_STR, IVec2), (GPU_TESS_UV_RANGE_STR, Vec4)])
end

# ? For Intersectable ParametricSurfaces.

struct PTrianglesOfSurface <: PrimitivesOf{PTriangle}
    _surfaceTriangleIterator::TrianglesOf
end
PrimitivesOf(self::ParametricSurfaceDependent) = return PTrianglesOfSurface(TrianglesOf(self._uvValues))

Base.length(self::PTrianglesOfSurface) = return length(self._surfaceTriangleIterator)

Base.getindex(self::PTrianglesOfSurface, index::UInt)::PTriangle = return self._surfaceTriangleIterator[index]

Base.iterate(self::PTrianglesOfSurface, state = (1,1,1)) = return iterate(self._surfaceTriangleIterator,state)   

# ? ---------------------------------
# ! ParametricSurfaceRenderer
# ? ---------------------------------

mutable struct ParametricSurfaceRenderer <: RendererDNA{ParametricSurfaceDependent}
    _renderer::Renderer{ParametricSurfaceDependent}
    _renderers::PrimitiveRenderers
    _refs::Vector{UInt32}

    _indexes::Vector{UInt32}
    _vertexes::FlatMatrixManager{Vec3F}
    _normals::FlatMatrixManager{Vec3F}

    # GREEN Thread
    function ParametricSurfaceRenderer(context::OpenGLData)
        renderer = Renderer{ParametricSurfaceDependent}(context)
        refs = Vector{UInt32}()
        
        new(renderer,context._renderers,refs,
        Vector{UInt32}(),FlatMatrixManager{Vec3F}(),FlatMatrixManager{Vec3F}())
    end
end

_Renderer_(self::ParametricSurfaceRenderer) = return self._renderer
Base.string(self::ParametricSurfaceRenderer) = "ParametricSurfaceRenderer - [$(length(self._refs))]"

# GREEN Thread
function added!(self::ParametricSurfaceRenderer,surface::ParametricSurfaceDependent)
    width = length(surface._uRange)
    height = length(surface._vRange)

    initMatrix(self._vertexes,width,height,Vec3FNan)
    initMatrix(self._normals,width,height,Vec3FNan)
    triangulateInto!(self._indexes,self._vertexes,layers(self._vertexes))
    
    # ? copy values
    copy!(surface._uvValues,self._vertexes,layers(self._vertexes))
    copy!(surface._uvNormals,self._normals,layers(self._normals))
    surface._layer = layers(self._vertexes)

    aID = UInt32(getGraphID(surface) + ID_LOWER_BOUND)
    coords = get_triangulated(data(self._vertexes, surface._layer),self._vertexes,layers(self._vertexes))
    ref = add!(
        self._renderers.triangle,
        coords,
        mat4(1.0f0),
        surface._color,
        surface._isInfinite,
        aID)
    push!(self._refs, ref)
end

# GREEN Thread
function sync!(self::ParametricSurfaceRenderer,surface::ParametricSurfaceDependent)
    copy!(surface._uvValues,self._vertexes,surface._layer)
    copy!(surface._uvNormals,self._normals,surface._layer)

    coords = get_triangulated(data(self._vertexes, surface._layer),self._vertexes,surface._layer)
    ref = self._refs[surface._layer]
    update_coords!(self._renderers.triangle,ref,coords)
end

# ! Must have
function destroy!(self::ParametricSurfaceRenderer)
end

# YELLOW Thread
Dependent2Observer(app::AppDNA,::ParametricSurfaceDependent)::ParametricSurfaceRenderer = getDependentObservers(app)[_SURFACES]

# ? ---------------------------------
# ! ParametricSurface
# ? ---------------------------------

# YELLOW Thread
function ParametricSurface(callback::Function,
                           uRange=range(0.0,1.0,50),vRange=range(0.0,1.0,50),
                           dependents::Vector{<:DependentDNA}=DependentDNA[],color_data::Union{Nothing,String}=nothing;
                           color="g", isInfinite::Bool=false, enable_gpu_tessellation::Bool=false,
                           callback_ast::Union{Expr,Nothing}=nothing,dependent_bindings::Union{Dict{Symbol,<:DependentDNA},Nothing}=nothing)
    if !enable_gpu_tessellation
        callback_ast = nothing
        dependent_bindings = nothing
    end
    c = isnothing(color_data) ? get_color(color) : get_color(color_data)
    Build!(ParametricSurfaceDependent(callback,dependents,uRange,vRange,c,callback_ast,dependent_bindings;isInfinite))
end

macro ParametricSurface(callback::Expr,uRange,vRange,args...)
    (positional_args, kw_args) = _parse_macro_arguments((:color_data,),(:color,:enable_gpu_tessellation), args...)
    callback = _validate_callback_expr(callback, 2)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.ParametricSurface,
                                positional_args,kw_args,
                                (cb, deps) -> (cb, uRange, vRange, deps), true)
end

export ParametricSurface
export @ParametricSurface