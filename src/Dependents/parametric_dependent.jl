const GPU_TESS_LOCAL_SIZE = 256
const GPU_TESS_POS_BINDING_IDX = 0
const GPU_TESS_DEBUG_ARG = "--debug-gpu-tess"
const GPU_TESS_SYNC_TIMEOUT_NS = 1_000_000

get_glsl_representation(::Type{T}) where {T<:DependentDNA} = Nothing
try_upload_dependent(uniform::GLint, dep::DependentDNA)::Bool = return false

module TessellationState
    # Pending - GPU work has been dispatched but not yet synchronized
    # Done - GPU calculated results have been read back into the proper CPU structures
    @enum TessellationStateValue Pending Done
end

# ? ---------------------------------
# ! ParametricDependentDNA
# ? ---------------------------------

mutable struct ParametricDependent <: RenderedDependentDNA
    _renderedDependent::RenderedDependent

    _callbackAST::Union{Expr,Nothing}
    _dependentBindings::Union{Dict{Symbol,<:DependentDNA},Nothing}
    _tessCompShader::Union{ShaderProgram,Nothing}
    _posBuffer::Union{MappedBuffer{Vec4},Nothing}
    _sampleCount::Int # num of vec4-s in pos buffer
    _stagingBuffer::Vector{Vec4}
    _tess_state::TessellationState.TessellationStateValue

    function ParametricDependent(callback::Function, dependents::Vector{<:DependentDNA}, sampleCount::Int = 0)
        renderedDependent = RenderedDependent(callback, dependents)
        return new(renderedDependent, nothing, nothing, nothing, nothing, sampleCount, Vec4[],
                   TessellationState.Done)
    end

    function ParametricDependent(callback::Function, dependents::Vector{<:DependentDNA},
        callbackAST::Expr, dependentBindings::Dict{Symbol,<:DependentDNA},
        sampleCount::Int)
        renderedDependent = RenderedDependent(callback, dependents)

        return new(renderedDependent, callbackAST, dependentBindings, nothing,
                   nothing, sampleCount, Vector{Vec4}(undef, sampleCount), TessellationState.Done)
    end
end

struct ParamDepPosBufferInfo
    _needsBuffer::Bool
    _cpuRead::Bool
    _cpuWrite::Bool
end

_ParametricDependent_(self::ParametricDependentDNA)::ParametricDependent = error("Missing \"_ParametricDependent_\" func for instance of ParametricDependentDNA")
_RenderedDependent_(self::ParametricDependentDNA)::RenderedDependent = _ParametricDependent_(self)._renderedDependent
_Subject_(self::ParametricDependentDNA)::Subject = _RenderedDependent_(self)._subject

# force GPU tessellated dependents to OpenGL's thread
thread_affinity(self::ParametricDependentDNA, ::Model) = is_gpu_tessellated(self) ? 0 : -1

# ensures GPU resources are initialized prior to first tessellation
function node_start!(self::ParametricDependentDNA)
    setup_parametric_dependent!(self)

    beforeNodeEval(self)
    onNodeEval(self)
    # force resolve dependents on first tessellation
    _resolve_pending_tessellations!()
    afterNodeEval(self)
end

function is_valid_parametric_dependent(self::ParametricDependentDNA)::Bool
    dep::ParametricDependent = _ParametricDependent_(self)
    gpu_props = (dep._callbackAST, dep._dependentBindings, dep._tessCompShader)
    return all(isnothing, gpu_props) || !any(isnothing, gpu_props)
end

is_gpu_tessellated(::DependentDNA)::Bool = false
is_gpu_tessellated(self::ParametricDependentDNA)::Bool = _ParametricDependent_(self)._tessCompShader !== nothing

is_cpu_tessellated(self::DependentDNA)::Bool = !is_gpu_tessellated(self)

function mark_pending!(self::ParametricDependentDNA)
    global implicitApp
    dep::ParametricDependent = _ParametricDependent_(self)
    
    dep._tess_state = TessellationState.Pending
    push!(implicitApp._pending_tessellations, self)

    implicitApp._tessellation_fence != C_NULL && glDeleteSync(implicitApp._tessellation_fence)
    implicitApp._tessellation_fence = glFenceSync(GL_SYNC_GPU_COMMANDS_COMPLETE, 0)
end

is_pending_tessellation(::DependentDNA)::Bool = false
is_pending_tessellation(self::ParametricDependentDNA)::Bool = _ParametricDependent_(self)._tess_state == TessellationState.Pending

pos_buffer_info(self::ParametricDependentDNA)::ParamDepPosBufferInfo =
    ParamDepPosBufferInfo(_ParametricDependent_(self)._tessCompShader !== nothing, true, false)

function force_cpu_tessellation!(self::ParametricDependentDNA)
    dep::ParametricDependent = _ParametricDependent_(self)

    dep._callbackAST = nothing
    dep._dependentBindings = nothing

    dep._tessCompShader !== nothing && destroy!(dep._tessCompShader)
    dep._tessCompShader = nothing

    if dep._posBuffer !== nothing && !pos_buffer_info(self)._needsBuffer
        dep._sampleCount = 0

        destroy!(dep._posBuffer)
        dep._posBuffer = nothing
    end
end

# must be invoked on opengl thread
try_transpile_tess_shader(::ParametricDependentDNA)::Union{ShaderProgram,Nothing} = error("Missing try_transpile_tess_shader func for instance of ParametricDependentDNA")

# must be invoked on opengl thread
function setup_parametric_dependent!(self::ParametricDependentDNA)
    dep::ParametricDependent = _ParametricDependent_(self)
    @assert dep._tessCompShader === nothing && dep._posBuffer === nothing "setup_parametric_dependent! called on dependent that has already been initialized"

    # GPU tessellated dependent
    if dep._callbackAST !== nothing
        @time_cpu_begin GPUTessSetup

        @time_cpu_begin GPUTessSetup CodeGen
        tess_shader = try_transpile_tess_shader(self)
        @time_cpu_end GPUTessSetup CodeGen

        if tess_shader !== nothing
            dep._tessCompShader = tess_shader
        else
            dep._callbackAST = nothing
            dep._dependentBindings = nothing
        end

        @time_cpu_end GPUTessSetup
    end

    pb_info = pos_buffer_info(self)
    if pb_info._needsBuffer
        @assert dep._sampleCount > 0 "Invalid sample count for parametric dependent that requires a position buffer"

        dep._posBuffer = MappedBuffer{Vec4}(; read = pb_info._cpuRead, write = pb_info._cpuWrite)
        reserve!(dep._posBuffer, dep._sampleCount, 0)
    end

    post_setup_parametric_dependent!(self)

    @assert is_valid_parametric_dependent(self) "parametric dependent in invalid state after setup"
end

# hook for any additional OpenGL setup
post_setup_parametric_dependent!(self::ParametricDependentDNA) = nothing

# called before the tessellation shader is dispatched, can be used for uniform uploads and such
pre_gpu_tess!(::ParametricDependentDNA) = nothing

function eval_callbacks!(self::ParametricDependentDNA)
    @assert is_valid_parametric_dependent(self) "eval_callbacks! called with uninitialized or otherwise invalid parametric dependent"

    if is_cpu_tessellated(self)
        @time_cpu_begin ParametricTessellation CPU
        eval_callbacks_cpu!(self)
        @time_cpu_end ParametricTessellation CPU
        return
    end

    @time_cpu_begin ParametricTessellation GPU Dispatch
    success = eval_callbacks_gpu!(self)
    @time_cpu_end ParametricTessellation GPU Dispatch

    success && return

    # unsuccessful gpu tessellation

    @log "Error during GPU tessellation of dependent #$(_Dependent_(self)._graphID), falling back to CPU" WARN

    force_cpu_tessellation!(self)

    @time_cpu_begin ParametricTessellation CPU
    eval_callbacks_cpu!(self)
    @time_cpu_end ParametricTessellation CPU
end

# should handle the entire CPU-side tessellation pipeline, including the updating of `self`
eval_callbacks_cpu!(self::ParametricDependentDNA) = error("Missing eval_callbacks_cpu! func for instance of ParametricDependentDNA")

# first dispatch in batch starts batch-level timer, must be called before dispatching
# returns whether this call started the batch
function try_begin_tess_batch!()::Bool
    global implicitApp

    isempty(implicitApp._pending_tessellations) || return false

    @time_gpu_begin ParametricTessellation GPU Dispatch UploadAndCompute

    return true
end

function eval_callbacks_gpu!(self::ParametricDependentDNA)::Bool
    batch_start = try_begin_tess_batch!()

    if !dispatch_gpu_tess(self)
        batch_start && @time_gpu_end ParametricTessellation GPU Dispatch UploadAndCompute
        return false
    end

    mark_pending!(self)

    return true
end

# dispatch GPU work
dispatch_gpu_tess(::ParametricDependentDNA)::Bool = error("Missing func dispatch_gpu_tess func for instance of ParametricDependentDNA")

# wait for and process GPU calculated data
resolve_gpu_tess!(::ParametricDependentDNA)::Bool = error("Missing func resolve_gpu_tess! func for instance of ParametricDependentDNA")

# Helper for dispatch_gpu_tess implementations
function dispatch_gpu_tess_compute(self::ParametricDependentDNA)::Bool
    dep::ParametricDependent = _ParametricDependent_(self)
    
    activate(dep._tessCompShader)

    pre_gpu_tess!(self)

    for (parent_sym, parent_dep) in dep._dependentBindings
        success = try_upload_dependent(maybe_uniform_loc(dep._tessCompShader, string(parent_sym)), parent_dep)
        if !success
            @log "Error while uploading dependencies to GPU" WARN
            return false
        end
    end

    bind_ssbo(dep._posBuffer, GPU_TESS_POS_BINDING_IDX)

    num_wg = div(dep._sampleCount + GPU_TESS_LOCAL_SIZE - 1, GPU_TESS_LOCAL_SIZE)

    glDispatchCompute(num_wg, 1, 1)

    return true
end

function _tess_client_sync()::Bool
    global implicitApp
    fence = implicitApp._tessellation_fence

    fence == C_NULL && return true

    wait_success = true
    while wait_success
        wait_return = glClientWaitSync(fence, GL_SYNC_FLUSH_COMMANDS_BIT, GPU_TESS_SYNC_TIMEOUT_NS)
        if wait_return == GL_ALREADY_SIGNALED || wait_return == GL_CONDITION_SATISFIED
            break
        elseif wait_return == GL_WAIT_FAILED
            @log "Error while synchronizing with the GPU during tessellation" WARN
            wait_success = false
            break
        end
    end

    glDeleteSync(fence)
    implicitApp._tessellation_fence = C_NULL

    return wait_success
end

function _resolve_pending_tessellations!()
    global implicitApp
    pending = implicitApp._pending_tessellations

    isempty(pending) && return

    # closes the timer started by the batch's first dispatch
    @time_gpu_end ParametricTessellation GPU Dispatch UploadAndCompute

    # shouldn't be needed since buffers are mapped coherently
    # glMemoryBarrier(GL_CLIENT_MAPPED_BUFFER_BARRIER_BIT)

    @time_cpu_begin ParametricTessellation GPU Resolve

    @time_cpu_begin ParametricTessellation GPU Resolve ClientWaitSync
    synced = _tess_client_sync()
    @time_cpu_end ParametricTessellation GPU Resolve ClientWaitSync

    @time_cpu_begin ParametricTessellation GPU Resolve DataProcessing
    
    # uses indexing because CPU fallback may submit additional GPU work, which are resolved in the next batch
    num_pending = length(pending)
    for i in 1:num_pending
        self = pending[i]
        _ParametricDependent_(self)._tess_state = TessellationState.Done
        
        if synced
            resolved = resolve_gpu_tess!(self)
            resolved && continue
        end

        # sync or data processing failed for a dependent
        force_cpu_tessellation!(self)
        onNodeEval(self)
    end
    deleteat!(pending, 1:num_pending)

    @time_cpu_end ParametricTessellation GPU Resolve DataProcessing

    @time_cpu_end ParametricTessellation GPU Resolve
end
