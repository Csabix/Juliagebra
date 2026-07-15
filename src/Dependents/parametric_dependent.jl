const GPU_TESS_LOCAL_SIZE = 256
const GPU_TESS_POS_BINDING_IDX = 0
const GPU_TESS_DEBUG_ARG = "--debug-gpu-tess"

# TODO: gui and other simple dependent uploads

get_glsl_representation(::Type{T}) where {T<:DependentDNA} = Nothing
try_upload_dependent(uniform::GLint, dep::DependentDNA)::Bool = return false

# ? ---------------------------------
# ! ParametricDependentDNA
# ? ---------------------------------

mutable struct ParametricDependent <: RenderedDependentDNA
    _renderedDependent::RenderedDependent
    
    _callbackAST::Union{Expr, Nothing}
    _dependentBindings::Union{Dict{Symbol, <:DependentDNA}, Nothing}
    _tessCompShader::Union{ShaderProgram, Nothing}
    _outBuffer::Union{MappedBuffer{Vec4}, Nothing}
    _sampleCount::Int # num of vec4-s in _outBuffer

    function ParametricDependent(callback::Function, dependents::Vector{<:DependentDNA})
        renderedDependent = RenderedDependent(callback,dependents)
        return new(renderedDependent, nothing, nothing, nothing, nothing, 0)
    end

    function ParametricDependent(callback::Function, dependents::Vector{<:DependentDNA},
                                 callbackAST::Expr, dependentBindings::Dict{Symbol, <:DependentDNA},
                                 sampleCount::Int)
        renderedDependent = RenderedDependent(callback,dependents)

        return new(renderedDependent, callbackAST, dependentBindings, nothing, nothing, sampleCount)
    end
end

_ParametricDependent_(self::ParametricDependentDNA)::ParametricDependent = error("Missing \"_ParametricDependent_\" func for instance of ParametricDependentDNA")
_RenderedDependent_(self::ParametricDependentDNA)::RenderedDependent = _ParametricDependent_(self)._renderedDependent
_Subject_(self::ParametricDependentDNA)::Subject = _RenderedDependent_(self)._subject

# force GPU tessellated dependents to OpenGL's thread
thread_affinity(self::ParametricDependentDNA, ::Model) = is_gpu_tessellated(self) ? 0 : -1

# ensures GPU resources are initialized prior to first tessellation
function node_start!(self::ParametricDependentDNA)
    start_time = time_ns()
    setup_parametric_dependent!(self)

    beforeNodeEval(self)
    onNodeEval(self)
    afterNodeEval(self)
end

function is_valid_parametric_dependent(self::ParametricDependentDNA)::Bool
    dep::ParametricDependent = _ParametricDependent_(self)
    gpu_props = (dep._callbackAST, dep._dependentBindings, dep._tessCompShader, dep._outBuffer)
    return all(isnothing, gpu_props) || !any(isnothing, gpu_props)
end

is_gpu_tessellated(self::DependentDNA)::Bool = false
is_gpu_tessellated(self::ParametricDependentDNA)::Bool = _ParametricDependent_(self)._tessCompShader !== nothing

is_cpu_tessellated(self::DependentDNA)::Bool = !is_gpu_tessellated(self)

function force_cpu_tessellation!(self::ParametricDependentDNA)
    dep::ParametricDependent = _ParametricDependent_(self)

    dep._callbackAST = nothing
    dep._dependentBindings = nothing
    dep._sampleCount = 0
    
    dep._tessCompShader !== nothing && destroy!(dep._tessCompShader)
    dep._tessCompShader = nothing
    
    dep._outBuffer !== nothing && destroy!(dep._outBuffer)
    dep._outBuffer = nothing
end

# must be invoked on opengl thread
try_transpile_tess_shader(::ParametricDependentDNA)::Union{ShaderProgram, Nothing} = error("Missing try_transpile_tess_shader func for instance of ParametricDependentDNA")

# must be invoked on opengl thread
function setup_parametric_dependent!(self::ParametricDependentDNA)
    dep::ParametricDependent = _ParametricDependent_(self)
    @assert dep._tessCompShader === nothing && dep._outBuffer === nothing "setup_parametric_dependent! called on dependent that has already been initialized"

    # CPU tessellated dependent
    dep._callbackAST === nothing && return

    @time_cpu_begin GPUTessSetup

    @time_cpu_begin GPUTessSetup CodeGen
    tess_shader = try_transpile_tess_shader(self)
    @time_cpu_end GPUTessSetup CodeGen
    
    if tess_shader !== nothing
        dep._tessCompShader = tess_shader

        dep._outBuffer = MappedBuffer{Vec4}(; read = true, write = false)
        reserve!(dep._outBuffer, dep._sampleCount, 0)
    else
        dep._callbackAST = nothing
        dep._dependentBindings = nothing
    end

    @assert is_valid_parametric_dependent(self) "parametric dependent in invalid state after setup"

    @time_cpu_end GPUTessSetup
end

# called before the tessellation shader is dispatched, can be used for uniform uploads and such
pre_gpu_tess!(::ParametricDependentDNA) = nothing

# Should update `self` according to the data read back from the GPU after tessellation
# This should be (mostly) equivalent to how the CPU tessellation updates the dependent
# _outBuffer has been updated and sync-d by the time this function is invoked
# False return value indicates failures and forces fallback to CPU tessellation
handle_gpu_tess_result!(self::ParametricDependentDNA)::Bool = error("Missing func handle_gpu_tess_result! func for instance of ParametricDependentDNA")

function eval_callbacks!(self::ParametricDependentDNA)
    @assert is_valid_parametric_dependent(self) "eval_callbacks! called with uninitialized or otherwise invalid parametric dependent"

    # TODO: timings

    if is_cpu_tessellated(self)
        eval_callbacks_cpu!(self)
        return
    end

    eval_callbacks_gpu!(self) && return

    # unsuccessful gpu tessellation

    @log "Error during GPU tessellation of dependent #$(_Dependent_(self)._graphID), falling back to CPU" WARN

    force_cpu_tessellation!(self)

    eval_callbacks_cpu!(self)
end

# should handle the entire CPU-side tessellation pipeline, including the updating of `self`
eval_callbacks_cpu!(self::ParametricDependentDNA) = error("Missing eval_callbacks_cpu! func for instance of ParametricDependentDNA")

function eval_callbacks_gpu!(self::ParametricDependentDNA)
    dep::ParametricDependent = _ParametricDependent_(self)

    activate(dep._tessCompShader)

    pre_gpu_tess!(self)

    for (parent_sym, parent_dep) in dep._dependentBindings
        success = try_upload_dependent(dep._tessCompShader.uniforms[string(parent_sym)], parent_dep)
        !success && return false
    end

    bind_ssbo(dep._outBuffer, GPU_TESS_POS_BINDING_IDX)

    num_wg = div(dep._sampleCount + GPU_TESS_LOCAL_SIZE - 1, GPU_TESS_LOCAL_SIZE)

    glDispatchCompute(num_wg, 1, 1)

    glMemoryBarrier(GL_CLIENT_MAPPED_BUFFER_BARRIER_BIT)

    fence = glFenceSync(GL_SYNC_GPU_COMMANDS_COMPLETE, 0)
    while true
        waitReturn = glClientWaitSync(fence, GL_SYNC_FLUSH_COMMANDS_BIT, 1000000)
        if waitReturn == GL_ALREADY_SIGNALED || waitReturn == GL_CONDITION_SATISFIED
            break
        elseif waitReturn == GL_WAIT_FAILED
            glDeleteSync(fence)
            return false
        end
    end
    glDeleteSync(fence)

    return handle_gpu_tess_result!(self)
end

