baremodule ParamTessMode
    import Base

    Base.@enum EnumType Uninitalized CPU GPU
    
    Base.show(io::IO, mode::EnumType) =
        Base.print(io, "ParamTessMode(", mode === CPU ? "CPU" : (mode === GPU ? "GPU" : "uninit"), ")")
end

# groups GPU resources for an initalized GPU tessellation state
mutable struct ParamGPUTessData
    # ? THESE ARE UPDATED ONCE PER GPU INIT

    shader::ShaderProgram # the computer shader used for tessellation

    # CPU-read-only MappedBuffer when readback is required, regular Buffer otherwise
    tess_buffer::BufferBase{Vec4} # output buffer of tessellation

    can_readback::Bool # whether the GPU state was set up for readback

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
    next_mode::Union{ParamTessMode.EnumType,Nothing}

    # stores the current GPU-representable form of arguments, mainly useful to reduce allocations per eval
    # external code should not rely on this
    gpu_argument_values::Dict{NodeHandle,Any}

    # indicates whether rendering can use gpu_data's tess_buffer as a data source during the next rendering rendering pass
    # NOTE: this being true only indicates that the renderer doesn't have to rely on CPU data, not that it hasn't been read back
    render_from_gpu::Bool

    # GPU tessellation candidate constructor
    function ParamTessData(callback_ast::Expr, argument_bindings::Dict{Symbol, NodeHandle},
                           node_uniforms::Dict{Symbol,DataType}, sample_count::Int)
        transpilation_src = TranspilationSource(callback_ast, [(sym, handle) for (sym, handle) in argument_bindings], node_uniforms)

        gpu_argument_values = Dict{NodeHandle,Any}()
        sizehint!(gpu_argument_values, length(argument_bindings))

        new(transpilation_src, nothing, sample_count, ParamTessMode.Uninitalized, nothing, gpu_argument_values, false)
    end

    # no GPU tessellation constructor
    ParamTessData(sample_count::Int) = 
        new(nothing, nothing, sample_count, ParamTessMode.Uninitalized, nothing, Dict{NodeHandle,Any}(), false)
end

update_node_uniforms!(uniform_values::Dict{Symbol,Any}, element::Any) = nothing

# handles processing the (already fenced) GPU result
# first return value indicates if conversion was successful, the second is the result passed to convert_callback_result
# (separation allows a successful readback to use nothing as a valid result)
convert_gpu_result(element::Any, tess_buffer::MappedBuffer{Vec4})::Tuple{Bool,Any} = (false, nothing)

# no-GPU-readback case, return value passed to convert_callback_result
convert_gpu_result(element::Any)::Any = element

# indicates whether the given geometry can render without the tessellation output being read back to the CPU
# renderer buffer size checks and such can be performed here
# other checking (children, tessellation buffer size) is performed automatically
can_render_without_readback(element::Any)::Bool = false

# helper the concrete node types can simply pass their param_tess_data to
needs_eval_on_new_child(param_tess_data::ParamTessData)::Bool = param_tess_data.current_mode === ParamTessMode.GPU && !param_tess_data.gpu_data.can_readback

# NOTE: the below thread restrictions don't apply if transpilation_src === nothing
# in that case no GPU init or cleanup will ever run on the ParamTessData, even if requested and
# the standard CPU fallback path is taken

# main thread only
# no-op if `param_tess_data` is not in GPU mode
function cleanup_gpu_data!(param_tess_data::ParamTessData)
    if param_tess_data.gpu_data === nothing
        return
    end

    destroy!(param_tess_data.gpu_data.shader)
    destroy!(param_tess_data.gpu_data.tess_buffer)

    param_tess_data.gpu_data = nothing
end

switch_mode!(::ParamTessData, ::Val{ParamTessMode.Uninitalized}) = 
    error("Cannot manually switch to the Uninitialized state!")

# main thread only (iff GPU cleanup is needed)
function switch_mode!(param_tess_data::ParamTessData, ::Val{ParamTessMode.CPU})::ParamTessMode.EnumType
    cleanup_gpu_data!(param_tess_data)

    param_tess_data.current_mode = ParamTessMode.CPU

    return ParamTessMode.CPU
end

# main thread only
function switch_mode!(param_tess_data::ParamTessData, ::Val{ParamTessMode.GPU}, gpu_argument_values::Dict{NodeHandle,Any}, needs_readback::Bool)::ParamTessMode.EnumType
    # we don't clean GPU data here, since the buffer might be reusable
    # fallback path early returns that switch to CPU mode clean up potential GPU resources automatically

    global implicitApp
    ogl_data::OpenGLData = implicitApp._opengl::OpenGLData

    dbg::Bool = GPU_TESS_DEBUG_ARG in ARGS

    if param_tess_data.transpilation_src === nothing
        dbg && println("Transpilation source data not available, falling back to CPU...")
        return switch_mode!(param_tess_data, Val(ParamTessMode.CPU))
    end

    # if the first is ever an issue, transpilation can be modified to use 2D dispatch like triangle_renderer compute passes
    hits_device_limits::Bool =
        cld(param_tess_data.sample_count,GPU_TESS_LOCAL_SIZE) > ogl_data._max_wg_count[1] ||
        param_tess_data.sample_count * sizeof(Vec4F) > ogl_data._max_shader_storage_block_size
    
    if hits_device_limits
        dbg && println("Compute work group size or tessellation buffer size exceeds device limits, falling back to CPU...")
        return switch_mode!(param_tess_data, Val(ParamTessMode.CPU))
    end

    has_gpu_compatible_args = true
    for (handle, value) in gpu_argument_values
        if value === nothing
            has_gpu_compatible_args = false

            if dbg
                sym_idx = findfirst(binding -> binding[2] == handle, param_tess_data.transpilation_src.argument_bindings)
                sym = sym_idx !== nothing ? param_tess_data.transpilation_src.argument_bindings[sym_idx][1] : :UNKNOWN

                entry_type = typeof(convert_callback_entry(get_element(handle)))
                println("A callback argument (named $sym, pointing to $handle) has an entry type that is not GPU compatible ($entry_type)")
            end

            # allows all problematic arguments to be logged at once during debugging
            !dbg && break
        end
    end

    if !has_gpu_compatible_args
        dbg && println("Node has GPU incompatible argument entry types, falling back to CPU...")
        return switch_mode!(param_tess_data, Val(ParamTessMode.CPU))
    end

    gpu_argument_types = Dict{NodeHandle,DataType}(handle => typeof(value) for (handle, value) in gpu_argument_values)

    shader = transpile_tess_shader(param_tess_data.transpilation_src, gpu_argument_types)

    if shader === nothing
        dbg && println("Shader transpilation failed, falling back to CPU...")
        return switch_mode!(param_tess_data, Val(ParamTessMode.CPU))
    end

    # if previous mode is GPU and tess_buffer properties match, we can just steal the already allocated buffer
    can_reuse_tess_buffer = param_tess_data.current_mode === ParamTessMode.GPU && 
                            param_tess_data.gpu_data.can_readback == needs_readback &&
                            length(param_tess_data.gpu_data.tess_buffer) == param_tess_data.sample_count

    tess_buffer = if can_reuse_tess_buffer
        param_tess_data.gpu_data.tess_buffer
    else
        cleanup_gpu_data!(param_tess_data)

        if needs_readback
            mapped = MappedBuffer{Vec4}(; read = true, write = false)
            reserve!(mapped, param_tess_data.sample_count, 0)
            mapped
        else
            buf = Buffer{Vec4}()
            reserve!(buf, param_tess_data.sample_count, 0)
            buf
        end
    end

    argument_uniform_locs::Dict{NodeHandle,GLint} = Dict{NodeHandle,GLint}(
        handle => maybe_uniform_loc(shader, String(sym)) for (sym, handle) in param_tess_data.transpilation_src.argument_bindings)

    node_uniform_locs::Dict{Symbol,GLint} = Dict{Symbol,GLint}(
        sym => maybe_uniform_loc(shader, String(sym)) for (sym, _) in param_tess_data.transpilation_src.node_uniforms)

    N_uniform_loc::GLint = maybe_uniform_loc(shader, GPU_TESS_N_STR)

    node_uniform_values::Dict{Symbol,Any} = Dict{Symbol,Any}()
    sizehint!(node_uniform_values, length(node_uniform_locs))

    param_tess_data.gpu_data !== nothing && destroy!(param_tess_data.gpu_data.shader)

    param_tess_data.gpu_data = ParamGPUTessData(shader, tess_buffer, needs_readback, gpu_argument_types,
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
    has_children::Bool = node.child_h !== nothing && !isempty(node.child_h)

    can_render_from_gpu::Bool = can_render_without_readback(element)
    needs_readback::Bool = has_children || !can_render_from_gpu

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
        switch_mode!(param_tess_data, Val(ParamTessMode.CPU))
    elseif target_mode === ParamTessMode.GPU
        switch_mode!(param_tess_data, Val(ParamTessMode.GPU), gpu_argument_values(), needs_readback)
    end

    # if the argument types changed since transpilation, retry transpilation
    # if it fails, we fall back to the CPU
    # this allows a dependency to change its projected type dynamically without
    # permanently invalidating its GPU-tessellated children
    if param_tess_data.current_mode === ParamTessMode.GPU
        gpu_data::ParamGPUTessData = param_tess_data.gpu_data::ParamGPUTessData
        gpu_arg_vals::Dict{NodeHandle,Any} = gpu_argument_values()

        has_stale_gpu_data =
            length(gpu_arg_vals) != length(gpu_data.argument_types) ||
            any(handle -> gpu_arg_vals[handle] === nothing || !haskey(gpu_data.argument_types, handle) ||
                        gpu_data.argument_types[handle] != typeof(gpu_arg_vals[handle]), keys(gpu_arg_vals)) ||
            length(gpu_data.tess_buffer) != param_tess_data.sample_count ||
            gpu_data.can_readback != needs_readback

        if has_stale_gpu_data
            dbg && println("GPU data is stale, reinitializing GPU state...")
            switch_mode!(param_tess_data, Val(ParamTessMode.GPU), gpu_arg_vals, needs_readback)
            if param_tess_data.current_mode === ParamTessMode.GPU
                gpu_data = param_tess_data.gpu_data # refetch GPU data so that it doesn't leave this if stmt stale
            end
        end
    end
    
    @assert param_tess_data.current_mode != ParamTessMode.Uninitalized

    param_tess_data.render_from_gpu = false

    eval_result = if param_tess_data.current_mode === ParamTessMode.CPU
        @time_cpu_begin ParamTess CPU Eval
        cpu_result = eval_node(element, node.callback, arguments)
        @time_cpu_end ParamTess CPU Eval

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

        # if we have child nodes, or hit other limitations we need to read back GPU data even if the renderer doesn't use it
        gpu_result = if needs_readback
            @assert gpu_data.can_readback

            @time_cpu_begin ParamTess GPU Eval FenceSync
            lock(gpu_data.tess_buffer)
            wait(gpu_data.tess_buffer)
            @time_cpu_end ParamTess GPU Eval FenceSync

            @time_cpu_begin ParamTess GPU Eval ProcessData
            success, result = convert_gpu_result(element, gpu_data.tess_buffer)
            @time_cpu_end ParamTess GPU Eval ProcessData

            @time_cpu_end ParamTess GPU Eval

            if success
                param_tess_data.render_from_gpu = can_render_from_gpu
            else
                dbg && println("GPU tessellation data processing failed, falling back to CPU state...")
                switch_mode!(param_tess_data, Val(ParamTessMode.CPU))

                @time_cpu_begin ParamTess CPU Eval
                result = eval_node(element, node.callback, arguments)
                @time_cpu_end ParamTess CPU Eval
            end

            result
        else
            @time_cpu_end ParamTess GPU Eval
            param_tess_data.render_from_gpu = true # !needs_readback already implies can_render_from_gpu
            convert_gpu_result(element)
        end

        param_tess_data.render_from_gpu && glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT)

        gpu_result
    end

    return convert_callback_result(element, eval_result)
end

# helper for providing an editor for general parametric tessellation properties
function edit_param_tess_data!(param_tess_data::ParamTessData,handle::NodeHandle)::Int
    result = EDIT_NODE_NONE

    extra_note = if param_tess_data.current_mode === ParamTessMode.GPU
        param_tess_data.gpu_data.can_readback ? " (with readback)" : " (without readback)"
    else
        ""
    end
    CImGui.Text("Tessellation Mode: $(param_tess_data.current_mode)$extra_note")

    CImGui.SameLine()
    if CImGui.Button("-> CPU##$(handle.value)")
        param_tess_data.next_mode = ParamTessMode.CPU
        result |= EDIT_NODE_INVALIDATE
    end

    CImGui.BeginDisabled(param_tess_data.transpilation_src === nothing)
    CImGui.SameLine()
    if CImGui.Button("-> GPU##$(handle.value)")
        param_tess_data.next_mode = ParamTessMode.GPU
        result |= EDIT_NODE_INVALIDATE
    end
    CImGui.EndDisabled()

    return result
end
