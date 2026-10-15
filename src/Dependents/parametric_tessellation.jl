baremodule ParamTessMode
    import Base

    Base.@enum EnumType Uninitalized CPU GPU
    
    Base.show(io::IO, mode::EnumType) =
        Base.print(io, "ParamTessMode(", mode === CPU ? "CPU" : (mode === GPU ? "GPU" : "uninitialized"), ")")
end

# groups GPU resources for an initalized GPU tessellation state
mutable struct ParamGPUTessData
    # ? THESE ARE UPDATED ONCE PER GPU INIT

    shader::ShaderProgram # the computer shader used for tessellation

    tess_buffer::Buffer{Vec4} # output buffer of tessellation

    # argument types (for dependents) have to be locked per transpiled shader
    # this is because if a node decides to change the type it returns for convert_callback_entry during runtime,
    # we have to detect that, since it'd change a uniform's type in the transpiled shader
    argument_types::Dict{NodeHandle,DataType}

    argument_uniform_locs::Dict{NodeHandle,GLint} # argument uniforms defined and updated automatically
    node_uniform_locs::Dict{Symbol,GLint} # additional uniforms defined and updated by the node (e.g. parameter ranges)
    N_uniform_loc::GLint # sample_count uniform

    # ? THESE ARE UPDATED ONCE PER EVAL

    # current values for each node uniform, kept up to date by the node via `update_node_uniforms!`
    # stored as a central field here to avoid per-eval Dict allocs
    node_uniform_values::Dict{Symbol,Any}
end

# this groups properties related to general parametric CPU/GPU tessellation flow
mutable struct ParamTessData
    # source data for producing a GPU tessellation state
    # intended to be generated once during node init, and used by gpu (re)init later
    transpilation_src::Union{TranspilationSource,Nothing}

    gpu_data::Union{ParamGPUTessData,Nothing}
    sample_count::Int # num of vertices produced by tessellation

    current_mode::ParamTessMode.EnumType
    
    # mode switching requires deferring, since only eval is guaranteed to run on the main thread
    # Union{..., Nothing} instead of being identical to `current_mode` in the idle case to allow reinitialization to same state
    # when setting this to GPU mode, NODE_EVAL_ON_MAIN should also be added to the node's flags so that the next eval can already make GL calls
    next_mode::Union{ParamTessMode.EnumType,Nothing}

    # stores the current GPU-representable form of arguments, mainly useful to reduce allocations per eval
    # external code should not rely on this
    gpu_argument_values::Dict{NodeHandle,Any}

    # GPU tessellation candidate constructor
    function ParamTessData(callback_ast::Expr, argument_bindings::Dict{Symbol, NodeHandle},
                           node_uniforms::Dict{Symbol,DataType}, sample_count::Int)
        transpilation_src = TranspilationSource(callback_ast, [(sym, handle) for (sym, handle) in argument_bindings], node_uniforms)

        gpu_argument_values = Dict{NodeHandle,Any}()
        sizehint!(gpu_argument_values, length(argument_bindings))

        new(transpilation_src, nothing, sample_count, ParamTessMode.Uninitalized, nothing, gpu_argument_values)
    end

    # no GPU tessellation constructor
    ParamTessData(sample_count::Int) = 
        new(nothing, nothing, sample_count, ParamTessMode.Uninitalized, nothing, Dict{NodeHandle,Any}())
end

update_node_uniforms!(uniform_values::Dict{Symbol,Any}, element::Any) = nothing

# handles processing the (already synchronized) GPU result
convert_gpu_result!(element::Any, tess_buffer::MappedBuffer{Vec4})::Nothing = nothing

# NOTE: the below thread restrictions don't apply if transpilation_src === nothing
# in that case no GPU init or cleanup will ever run on the ParamTessData, even if requested and
# the standard CPU fallback path is taken

# main thread only
# no-op if `param_tess_data` is not in GPU mode
function cleanup_gpu_data!(param_tess_data::ParamTessData)
    param_tess_data.gpu_data === nothing && return

    destroy!(param_tess_data.gpu_data.shader)
    destroy!(param_tess_data.gpu_data.tess_buffer)
    param_tess_data.gpu_data = nothing
end

switch_mode!(::ParamTessData, ::Val{ParamTessMode.Uninitalized}) = 
    error("Cannot manually switch to the Uninitialized state")

# main thread only iff GPU cleanup is needed
function switch_mode!(param_tess_data::ParamTessData, ::Val{ParamTessMode.CPU}, node::GeometryPlotNode)::ParamTessMode.EnumType
    cleanup_gpu_data!(param_tess_data)

    unset_geom_flags!(node, NODE_EVAL_ON_MAIN)
    param_tess_data.current_mode = ParamTessMode.CPU

    return ParamTessMode.CPU
end

# main thread only
function switch_mode!(param_tess_data::ParamTessData, ::Val{ParamTessMode.GPU}, node::GeometryPlotNode, gpu_argument_values::Dict{NodeHandle,Any})::ParamTessMode.EnumType
    # we don't clean GPU data here, since the buffer might be reusable
    # fallback path early returns that switch to CPU mode clean up potential GPU resources automatically

    global implicitApp
    ogl_data::OpenGLData = implicitApp._opengl::OpenGLData

    dbg::Bool = GPU_TESS_DEBUG_ARG in ARGS

    if param_tess_data.transpilation_src === nothing
        @log "Transpilation source data not available for parametric node, falling back to CPU..." WARN
        return switch_mode!(param_tess_data, Val(ParamTessMode.CPU), node)
    end

    # if the first is ever an issue, transpilation can be modified to use 2D dispatch like triangle_renderer compute passes
    hits_device_limits::Bool =
        cld(param_tess_data.sample_count,GPU_TESS_LOCAL_SIZE) > ogl_data._max_wg_count[1] ||
        param_tess_data.sample_count * sizeof(Vec4F) > ogl_data._max_shader_storage_block_size
    
    if hits_device_limits
        @log "Compute work group size or tessellation buffer size exceeds device limits for parametric node, falling back to CPU..." WARN
        return switch_mode!(param_tess_data, Val(ParamTessMode.CPU), node)
    end

    has_gpu_compatible_args = true
    for (handle, value) in gpu_argument_values
        value !== nothing && continue

        has_gpu_compatible_args = false

        sym_idx = findfirst(binding -> binding[2] == handle, param_tess_data.transpilation_src.argument_bindings)
        sym = sym_idx !== nothing ? param_tess_data.transpilation_src.argument_bindings[sym_idx][1] : :UNKNOWN
        entry_type = typeof(convert_callback_entry(get_element(handle)))
        @log "A callback argument (named $sym, pointing to handle #$(handle.value)) has an entry type that is not GPU compatible ($entry_type)" WARN
    end

    if !has_gpu_compatible_args
        @log "Parametric node has GPU incompatible argument entry types, falling back to CPU..." WARN
        return switch_mode!(param_tess_data, Val(ParamTessMode.CPU), node)
    end

    gpu_argument_types = Dict{NodeHandle,DataType}(handle => typeof(value) for (handle, value) in gpu_argument_values)

    shader = transpile_tess_shader(param_tess_data.transpilation_src, gpu_argument_types)

    if shader === nothing
        @log "Shader transpilation for parametric node failed, run with --debug-gpu-tess to get the detailed transpiler error messages. Falling back to CPU..." WARN
        return switch_mode!(param_tess_data, Val(ParamTessMode.CPU), node)
    end

    # if previous mode is GPU and tess_buffer properties match, we can just steal the already allocated buffer
    can_reuse_tess_buffer = param_tess_data.current_mode === ParamTessMode.GPU && 
                            length(param_tess_data.gpu_data.tess_buffer) == param_tess_data.sample_count

    tess_buffer = if can_reuse_tess_buffer
        param_tess_data.gpu_data.tess_buffer
    else
        cleanup_gpu_data!(param_tess_data)
        buf = Buffer{Vec4}()
        reserve!(buf, param_tess_data.sample_count, 0)
        buf
    end

    argument_uniform_locs::Dict{NodeHandle,GLint} = Dict{NodeHandle,GLint}(
        handle => maybe_uniform_loc(shader, String(sym)) for (sym, handle) in param_tess_data.transpilation_src.argument_bindings)

    node_uniform_locs::Dict{Symbol,GLint} = Dict{Symbol,GLint}(
        sym => maybe_uniform_loc(shader, String(sym)) for (sym, _) in param_tess_data.transpilation_src.node_uniforms)

    N_uniform_loc::GLint = maybe_uniform_loc(shader, GPU_TESS_N_STR)

    node_uniform_values::Dict{Symbol,Any} = Dict{Symbol,Any}()
    sizehint!(node_uniform_values, length(node_uniform_locs))

    param_tess_data.gpu_data !== nothing && destroy!(param_tess_data.gpu_data.shader)

    param_tess_data.gpu_data = ParamGPUTessData(shader, tess_buffer, gpu_argument_types,
                                                argument_uniform_locs, node_uniform_locs, N_uniform_loc,
                                                node_uniform_values)

    param_tess_data.current_mode = ParamTessMode.GPU
    return ParamTessMode.GPU
end

# main thread only
# meant to be invoked from eval_geometry_node
# acts a helper for cpu/gpu tessellation
function handle_param_tess!(param_tess_data::ParamTessData, element::Any, node::GeometryPlotNode, elements::Vector{Any})
    dbg::Bool = GPU_TESS_DEBUG_ARG in ARGS

    arguments::Vector{Any} = if node.parent_h === nothing
        Any[]
    else
        Any[convert_callback_entry(elements[p_h]) for p_h in node.parent_h]
    end

    # GPU argument projection is only updated lazily, if it's actually needed
    # it also happens in-place on the ParamTessData to reduce per-eval allocations
    _updated_gpu_value_list = false
    function gpu_argument_values()::Dict{NodeHandle,Any}
        _updated_gpu_value_list && return param_tess_data.gpu_argument_values

        empty!(param_tess_data.gpu_argument_values)
        for (par_idx, arg_val) in enumerate(arguments)
            param_tess_data.gpu_argument_values[node.parent_h[par_idx]] = convert_argument_gpu(arg_val)
        end

        _updated_gpu_value_list = true
        return param_tess_data.gpu_argument_values
    end

    target_mode::Union{ParamTessMode.EnumType,Nothing} = nothing

    if param_tess_data.next_mode !== nothing
        param_tess_data.next_mode === ParamTessMode.Uninitalized && error("'Uninitialized' is not a valid value as a ParamTessData's next mode!")
        target_mode = param_tess_data.next_mode
        param_tess_data.next_mode = nothing
    end

    if target_mode === nothing && param_tess_data.current_mode === ParamTessMode.Uninitalized
        target_mode = param_tess_data.transpilation_src !== nothing ? ParamTessMode.GPU : ParamTessMode.CPU
    end

    target_mode !== nothing && dbg && println("New target mode: $target_mode, switching...")
    if target_mode === ParamTessMode.CPU
        switch_mode!(param_tess_data, Val(ParamTessMode.CPU), node)
    elseif target_mode === ParamTessMode.GPU
        switch_mode!(param_tess_data, Val(ParamTessMode.GPU), node, gpu_argument_values())
    end

    # if the argument types changed since transpilation, retry transpilation. if that fails, we fall back to the CPU
    # this allows a dependency to change its projected type dynamically without permanently invalidating its GPU-tessellated children
    if param_tess_data.current_mode === ParamTessMode.GPU
        gpu_data::ParamGPUTessData = param_tess_data.gpu_data::ParamGPUTessData
        gpu_arg_vals::Dict{NodeHandle,Any} = gpu_argument_values()

        has_stale_gpu_data =
            length(gpu_arg_vals) != length(gpu_data.argument_types) ||
            any(handle -> gpu_arg_vals[handle] === nothing || !haskey(gpu_data.argument_types, handle) ||
                        gpu_data.argument_types[handle] != typeof(gpu_arg_vals[handle]), keys(gpu_arg_vals)) ||
            length(gpu_data.tess_buffer) != param_tess_data.sample_count

        if has_stale_gpu_data
            dbg && println("GPU data is stale, reinitializing GPU state...")
            switch_mode!(param_tess_data, Val(ParamTessMode.GPU), node, gpu_arg_vals)
            if param_tess_data.current_mode === ParamTessMode.GPU
                gpu_data = param_tess_data.gpu_data # refetch GPU data so that it doesn't leave this if stmt stale
            end
        end
    end

    @assert param_tess_data.current_mode != ParamTessMode.Uninitalized

    eval_result = if param_tess_data.current_mode === ParamTessMode.CPU
        on_main_thread = Threads.threadid() == 1
        on_main_thread && @time_cpu_begin ParamTess CPU Eval
        cpu_result = eval_node(element, node.callback, arguments)
        on_main_thread && @time_cpu_end ParamTess CPU Eval

        cpu_result
    else
        @time_cpu_begin ParamTess GPU Eval

        @time_gpu_begin ParamTess GPU Eval Compute
        activate(gpu_data.shader)
        bind_ssbo(gpu_data.tess_buffer, 0)

        for (handle, value) in gpu_argument_values()
            glUniform(gpu_data.argument_uniform_locs[handle], value)
        end

        glUniform(gpu_data.N_uniform_loc, GLuint(param_tess_data.sample_count))

        update_node_uniforms!(gpu_data.node_uniform_values, element)
        for (uni_sym, uni_value) in gpu_data.node_uniform_values
            glUniform(gpu_data.node_uniform_locs[uni_sym], uni_value)
        end

        num_wg = cld(param_tess_data.sample_count, GPU_TESS_LOCAL_SIZE)
        glDispatchCompute(num_wg, 1, 1)
        @time_gpu_end ParamTess GPU Eval Compute
        @time_cpu_end ParamTess GPU Eval

        element
    end

    return convert_callback_result(element, eval_result)
end

# helper for providing an editor for general parametric tessellation properties
function edit_param_tess_data!(param_tess_data::ParamTessData,handle::NodeHandle)::Int
    global implicitApp
    app::App = implicitApp::App
    
    result = EDIT_NODE_NONE

    CImGui.Text("Tessellation Mode: $(param_tess_data.current_mode)")

    CImGui.SameLine()
    if CImGui.Button("-> CPU##$(handle.value)")
        # we don't unset NODE_EVAL_ON_MAIN here since GPU cleanup still needs to happen in the next eval
        param_tess_data.next_mode = ParamTessMode.CPU
        result |= EDIT_NODE_INVALIDATE
    end

    CImGui.BeginDisabled(param_tess_data.transpilation_src === nothing)
    CImGui.SameLine()
    if CImGui.Button("-> GPU##$(handle.value)")
        set_geom_flags!(app.graph.nodes[handle], NODE_EVAL_ON_MAIN)
        param_tess_data.next_mode = ParamTessMode.GPU
        result |= EDIT_NODE_INVALIDATE
    end
    CImGui.EndDisabled()

    return result
end

on_window_clear() do
    app::App = implicitApp::App
    for element in app.graph.elements
        param_tess_data = get_param_tess_data(element)
        param_tess_data !== nothing && cleanup_gpu_data!(param_tess_data)
    end
end

# ? ----------------------------
# ! tessellation CPU readback
# ? ----------------------------

mutable struct TessellationSynchronizer
    target_h::NodeHandle # the node to sync, must be the parent of the synchronizer
    readback_buffer::Union{MappedBuffer{Vec4},Nothing}
end

const _tess_synchronizer_cache::Dict{NodeHandle, NodeHandle} = Dict{NodeHandle, NodeHandle}()
on_window_clear() do
    for syncer_h in values(_tess_synchronizer_cache)
        syncer = get_element(syncer_h)
        syncer.readback_buffer !== nothing && destroy!(syncer.readback_buffer)
    end
    empty!(_tess_synchronizer_cache)
end

get_param_tess_data(element::Any)::Union{ParamTessData,Nothing} = nothing

# NOTE: this assumes that a synchronizer node can only ever exist with a single parametric node parent, whose handle is target_h
function eval_geometry_node(ts::TessellationSynchronizer, node::GeometryPlotNode, elements::Vector{Any})::Any
    if node.parent_h === nothing || get(node.parent_h, 1, nothing) != ts.target_h
        error("a TessellationSynchronizer node can only have a single parent, its sync target")
    end
    target = elements[ts.target_h]

    maybe_param_tess_data = get_param_tess_data(target)
    maybe_param_tess_data === nothing && error("get_param_tess_data not implemented for target of a TessellationSynchronizer")
    param_tess_data::ParamTessData = maybe_param_tess_data::ParamTessData

    # CPU-tessellated case
    if param_tess_data.current_mode !== ParamTessMode.GPU
        if ts.readback_buffer !== nothing
            destroy!(ts.readback_buffer)
            ts.readback_buffer = nothing
        end
        return ts
    end

    @assert param_tess_data.gpu_data !== nothing "a GPU-tessellated parametric node has no GPU data"
    gpu_data::ParamGPUTessData = param_tess_data.gpu_data::ParamGPUTessData

    if ts.readback_buffer === nothing
        ts.readback_buffer = MappedBuffer{Vec4}(; write=false, read=true)
    end

    @assert size(ts.readback_buffer) % sizeof(eltype(ts.readback_buffer)) == 0 "unexpected readback buffer size"
    readback_buffer_count = div(size(ts.readback_buffer), sizeof(eltype(ts.readback_buffer)))
    if readback_buffer_count != param_tess_data.sample_count
        reserve!(ts.readback_buffer, param_tess_data.sample_count, 0)
    end

    @time_cpu_begin ParamTess GPU Sync
    @time_gpu_begin ParamTess GPU Sync Copy
    glMemoryBarrier(GL_BUFFER_UPDATE_BARRIER_BIT)
    glCopyNamedBufferSubData(gpu_data.tess_buffer._id, ts.readback_buffer._id, 0, 0, size(gpu_data.tess_buffer))
    @time_gpu_end ParamTess GPU Sync Copy

    @time_cpu_begin ParamTess GPU Sync Fence
    lock(ts.readback_buffer)
    wait(ts.readback_buffer)
    @time_cpu_end ParamTess GPU Sync Fence

    @time_cpu_begin ParamTess GPU Sync ProcessData
    convert_gpu_result!(target, ts.readback_buffer)
    @time_cpu_end ParamTess GPU Sync ProcessData
    @time_cpu_end ParamTess GPU Sync

    return ts
end

convert_callback_entry(ts::TessellationSynchronizer) = convert_callback_entry(get_element(ts.target_h))

PrimitivesOf(ts::TessellationSynchronizer) = PrimitivesOf(get_element(ts.target_h))

# nodes can decide dynamically whether they need a synchronizer inserted between them and their children
function _needs_tess_synchronizer(element::Any)::Bool
    param_tess_data = get_param_tess_data(element)
    return param_tess_data !== nothing ? param_tess_data.transpilation_src !== nothing : false
end

function _get_tess_synchronizer!(target_h::NodeHandle)
    get!(_tess_synchronizer_cache, target_h) do
        add_node!(TessellationSynchronizer(target_h, nothing); parents=[target_h], use_main_thread=true)
    end
end
