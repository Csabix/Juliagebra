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

    pos_buffer::MappedBuffer{Vec4} # output buffer of tessellation

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
    # Union{..., Nothing} instead of being identical to `current_mode` in the idle case to allow reinitialization
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

# first return value indicates if conversion was successful, the second is the result
# (this allows a successful readback to use nothing as a valid result)
convert_gpu_result(element::Any, pos_buffer::MappedBuffer{Vec4})::Tuple{Bool,Any} = (false, nothing)

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
    destroy!(param_tess_data.gpu_data.pos_buffer)
    
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
function switch_mode!(param_tess_data::ParamTessData, ::Val{ParamTessMode.GPU}, gpu_argument_values::Dict{NodeHandle,Any};
                      pos_buffer_read::Bool, pos_buffer_write::Bool)::ParamTessMode.EnumType
    # we don't clean GPU data here, since it may be partially reusable
    # early fallback path returns that switch to CPU mode clean up potential GPU resources automatically

    if param_tess_data.transpilation_src === nothing
        return switch_mode!(param_tess_data, Val(ParamTessMode.CPU))
    end

    has_gpu_compatible_args = true
    for (handle, value) in gpu_argument_values
        if value === nothing
            has_gpu_compatible_args = false

            if GPU_TESS_DEBUG_ARG in ARGS
                sym_idx = findfirst(binding -> binding[2] == handle, param_tess_data.transpilation_src.argument_bindings)
                sym = if sym_idx !== nothing
                    param_tess_data.transpilation_src.argument_bindings[sym_idx][1]
                else
                    :UNKNOWN
                end

                entry_type = typeof(convert_callback_entry(get_element(handle)))
                @log "a callback argument (named $sym, pointing to $handle) has an entry type that is not GPU compatible ($entry_type)"
            end

            break
        end
    end

    if !has_gpu_compatible_args
        return switch_mode!(param_tess_data, Val(ParamTessMode.CPU))
    end

    gpu_argument_types = Dict{NodeHandle,DataType}(handle => typeof(value) for (handle, value) in gpu_argument_values)

    shader = transpile_tess_shader(param_tess_data.transpilation_src, gpu_argument_types)

    if shader === nothing
        return switch_mode!(param_tess_data, Val(ParamTessMode.CPU))
    end

    # if previous mode is GPU and pos_buffer properties match, we can just steal the already allocated buffer
    can_reuse_pos_buffer = param_tess_data.current_mode === ParamTessMode.GPU && 
                           param_tess_data.gpu_data.pos_buffer._write == pos_buffer_write &&
                           param_tess_data.gpu_data.pos_buffer._read == pos_buffer_read &&
                           length(param_tess_data.gpu_data.pos_buffer) == param_tess_data.sample_count

    if can_reuse_pos_buffer
        pos_buffer = param_tess_data.gpu_data.pos_buffer
    else
        cleanup_gpu_data!(param_tess_data)

        pos_buffer = MappedBuffer{Vec4}(; read = pos_buffer_read, write = pos_buffer_write)
        reserve!(pos_buffer, param_tess_data.sample_count, 0)
    end

    argument_uniform_locs::Dict{NodeHandle,GLint} = Dict{NodeHandle,GLint}(
        handle => maybe_uniform_loc(shader, String(sym)) for (sym, handle) in param_tess_data.transpilation_src.argument_bindings
    )

    node_uniform_locs::Dict{Symbol,GLint} = Dict{Symbol,GLint}(
        sym => maybe_uniform_loc(shader, String(sym)) for (sym, _) in param_tess_data.transpilation_src.node_uniforms
    )

    N_uniform_loc::GLint = maybe_uniform_loc(shader, GPU_TESS_N_STR)

    node_uniform_values::Dict{Symbol,Any} = Dict{Symbol,Any}()
    sizehint!(node_uniform_values, length(node_uniform_locs))

    if param_tess_data.gpu_data !== nothing
        destroy!(param_tess_data.gpu_data.shader)
    end

    param_tess_data.gpu_data = ParamGPUTessData(shader, pos_buffer, gpu_argument_types,
                                                argument_uniform_locs, node_uniform_locs, N_uniform_loc,
                                                node_uniform_values)

    param_tess_data.current_mode = ParamTessMode.GPU
    return ParamTessMode.GPU
end

# main thread only
# meant to be invoked from eval_geometry_node
# acts a helper for cpu/gpu tessellation
function handle_param_tess!(param_tess_data::ParamTessData, element::Any, node::GeometryPlotNode, elements::Vector{Any};
                            pos_buffer_read::Bool, pos_buffer_write::Bool)
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
        if param_tess_data.next_mode === ParamTessMode.Uninitalized
            error("'Uninitialized' is not a valid value as a ParamTessData's next mode!")
        end

        target_mode = param_tess_data.next_mode
        param_tess_data.next_mode = nothing
    end

    if target_mode === nothing && param_tess_data.current_mode === ParamTessMode.Uninitalized
        target_mode = param_tess_data.transpilation_src !== nothing ? ParamTessMode.GPU : ParamTessMode.CPU
    end

    if target_mode === ParamTessMode.CPU
        switch_mode!(param_tess_data, Val(ParamTessMode.CPU))
    elseif target_mode === ParamTessMode.GPU
        switch_mode!(param_tess_data, Val(ParamTessMode.GPU), gpu_argument_values(); pos_buffer_read, pos_buffer_write)
    end

    # if the argument types changed since transpilation, retry transpilation
    # if it fails, we fall back to the CPU
    # this allows a dependency to change its projected type dynamically without
    # permanently invalidating its GPU-tessellated children
    if param_tess_data.current_mode === ParamTessMode.GPU
        gpu_data::ParamGPUTessData = param_tess_data.gpu_data
        gpu_arg_vals::Dict{NodeHandle,Any} = gpu_argument_values()

        has_stale_gpu_data =
            length(gpu_arg_vals) != length(gpu_data.argument_types) ||
            any(handle -> gpu_arg_vals[handle] === nothing || !haskey(gpu_data.argument_types, handle) ||
                        gpu_data.argument_types[handle] != typeof(gpu_arg_vals[handle]), keys(gpu_arg_vals)
            ) || length(gpu_data.pos_buffer) != param_tess_data.sample_count
        
        if has_stale_gpu_data
            switch_mode!(param_tess_data, Val(ParamTessMode.GPU), gpu_arg_vals; pos_buffer_read, pos_buffer_write)
        end
    end
    
    @assert param_tess_data.current_mode != ParamTessMode.Uninitalized

    eval_result = if param_tess_data.current_mode === ParamTessMode.CPU
        @time_cpu_begin ParamTess CPU Eval
        cpu_result = eval_node(element, node.callback, arguments)
        @time_cpu_end ParamTess CPU Eval

        cpu_result
    else
        @time "GPU eval" begin
            @time_cpu_begin ParamTess GPU Eval

            @time_gpu_begin ParamTess GPU Eval Compute
            activate(gpu_data.shader)
            bind_ssbo(gpu_data.pos_buffer, 0)

            for (handle, value) in gpu_argument_values()
                glUniform(gpu_data.argument_uniform_locs[handle], value)
            end

            glUniform(gpu_data.N_uniform_loc, GLuint(param_tess_data.sample_count))

            update_node_uniforms!(gpu_data.node_uniform_values, element)
            for (uni_sym, uni_value) in gpu_data.node_uniform_values
                glUniform(gpu_data.node_uniform_locs[uni_sym], uni_value)
            end

            num_wg = div(param_tess_data.sample_count + GPU_TESS_LOCAL_SIZE - 1, GPU_TESS_LOCAL_SIZE)
            glDispatchCompute(num_wg, 1, 1)
            @time_gpu_end ParamTess GPU Eval Compute

            @time_cpu_begin ParamTess GPU Eval Sync
            lock(gpu_data.pos_buffer)
            wait(gpu_data.pos_buffer)
            @time_cpu_end ParamTess GPU Eval Sync

            @time_cpu_begin ParamTess GPU Eval ProcessData
            success, gpu_result = convert_gpu_result(element,gpu_data.pos_buffer)
            @time_cpu_end ParamTess GPU Eval ProcessData
            
            @time_cpu_end ParamTess GPU Eval
        end

        if !success
            switch_mode!(param_tess_data, Val(ParamTessMode.CPU))

            @time_cpu_begin ParamTess CPU Eval
            gpu_result = eval_node(element, node.callback, arguments)
            @time_cpu_end ParamTess CPU Eval
        end

        gpu_result
    end

    return convert_callback_result(element, eval_result)
end
