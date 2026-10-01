# identifiers used in generated tessellation shaders
const GPU_TESS_N = :JG_TESS_N
const GPU_TESS_N_STR = string(GPU_TESS_N)
const GPU_TESS_BUF = :JG_TESS_BUFFER
const GPU_TESS_COORD_ARR = :JG_TESS_COORD_ARRAY
const GPU_TESS_CB = :JG_TESS_CALLBACK
const GPU_TESS_ID = :JG_TESS_ID

# ! TODO: place in a more relevant file
const GPU_TESS_DEBUG_ARG = "--debug-gpu-tess"
const GPU_TESS_BUF_BINDING_IDX = 0

mutable struct TranspilationSource
    callback_ast::Expr
    argument_bindings::Vector{Tuple{Symbol,NodeHandle}}
    node_uniforms::Dict{Symbol,DataType}

    function TranspilationSource(callback_ast::Expr, argument_bindings::Vector{Tuple{Symbol,NodeHandle}},
                               node_uniforms::Dict{Symbol,DataType}=Dict{Symbol,DataType}())
        new(callback_ast, argument_bindings, node_uniforms)
    end
end

# only meant to support types that convert_argument_gpu can actually produce
_parse_curly_type(T::DataType)::Union{Expr,Symbol} = 
    isempty(T.parameters) ? nameof(T) : Expr(:curly, nameof(T), _parse_curly_type.(T.parameters)...)
_parse_curly_type(::Type{<:SMatrix{N,M,T}}) where {N,M,T} = :(MatNxMT{$N,$M,$(_parse_curly_type(T))})

# transpiles, compiles and links the compute shader for GPU tessellation
# argument_types should reflect the current argument types
# this is available, since shaders are transpiled lazily, before tessellation
function transpile_tess_shader(src::TranspilationSource, argument_types::Dict{NodeHandle,DataType})::Union{ShaderProgram,Nothing}
    global implicitApp
    # this is an internal error, not a transpilation failure
    implicitApp === nothing && error("Trying to invoke shader transpilation before implicitApp has been initialized")

    dbg::Bool = GPU_TESS_DEBUG_ARG in ARGS

    if !_is_normalized_callback(src.callback_ast)
        dbg && @log "AST provided as a callback is not of normalized callback form" INFO
        return nothing
    end

    translation_unit = Expr(:block)
    top_cmpd = translation_unit.args

    push!(top_cmpd, :(
        @gl_buffer @gl_restrict @gl_writeonly @gl_layout(
            std430, binding = $GPU_TESS_BUF_BINDING_IDX,
            struct $GPU_TESS_BUF
                $(GPU_TESS_COORD_ARR)::Vector{Vec4}
            end
        ))
    )

    push!(top_cmpd, :(@gl_uniform global $GPU_TESS_N::UInt32))

    for (uni_name, uni_type) in src.node_uniforms
        push!(top_cmpd, :(@gl_uniform global $uni_name::$(_parse_curly_type(uni_type))))
    end

    for (arg_sym, arg_handle) in src.argument_bindings
        arg_type = get(argument_types, arg_handle, nothing)
        if arg_type === nothing
            dbg && @log "argument_types contains no entry for binding `$arg_sym`"
            return nothing
        end
        push!(top_cmpd, :(@gl_uniform global $arg_sym::$(_parse_curly_type(arg_type))))
    end

    append!(top_cmpd, implicitApp._callback_helpers)

    # only the body is carried over: the callback's own arguments are dropped and recomputed
    # from GPU_TESS_ID by the caller, and an explicit return type, if any, is overwritten
    push!(top_cmpd, Expr(:function, :($GPU_TESS_CB($GPU_TESS_ID::UInt32)::Vec3F), src.callback_ast.args[2]))

    main_body = Expr(:block,
        :($GPU_TESS_ID = gl_GlobalInvocationID.x),
        :(
            if $GPU_TESS_ID >= $GPU_TESS_N
                return
            end
        ),
        # ! w = 1 so that the buffer can be passed as-is to surface rendering 
        :($GPU_TESS_COORD_ARR[$GPU_TESS_ID + UInt32(1)] = Vec4F($GPU_TESS_CB($GPU_TESS_ID), 1))
    )

    push!(top_cmpd, Expr(:function, :(main()::Nothing), main_body))

    cfg = implicitApp._transpiler_cfg

    if dbg
        println("code passed to transpiler:")
        println(MacroTools.striplines(translation_unit))
    end

    pipe = Pipe()
    glsl_code::Union{String,Nothing} =
        try
            redirect_stderr(pipe) do
                ShaderTranspiler.transpile(translation_unit; run_benchmarks=dbg, cfg)
            end
        catch ex
            if dbg
                @log "an unexpected error occured during transpilation, see stderr for details" INFO
                println(stderr, ex)
            end

            nothing
        finally
            close(pipe.in)
        end

    stderr_output = read(pipe.out, String)
    close(pipe.out)

    if glsl_code === nothing || isempty(glsl_code)
        dbg && @log "callback code couldn't be transpiled" INFO

        if dbg && !isempty(stderr_output)
            @log "the transpiler printed errors, see stderr for details" INFO
            println(stderr, stderr_output)
        end

        return nothing
    end

    if dbg
        @log "successful transpilation, result printed to stdout" INFO
        println(glsl_code)
    end

    # this is intentionally flagged in non-dbg mode as well
    if !isempty(stderr_output)
        @log "transpilation seems to have finished successfully, but the lib printed to stderr during execution:" WARN
        @log stderr_output INFO
    end

    # creates unique file in default temp directory
    path = tempname() * ".comp"
    
    return open(path, "w") do io
        write(io, glsl_code)
        close(io)

        return try
            sp = ShaderProgram([path], [
                GPU_TESS_N_STR,
                String.(collect(keys(src.node_uniforms)))...,
                String.(first.(src.argument_bindings))...
            ])

            if sp.id != GLuint(0)
                sp
            else
                dbg && @log "couldn't create ShaderProgram from generated code"
                nothing
            end
        catch ex
            if dbg
                @log "error thrown while creating ShaderProgram from generated code, exception printed to stderr" INFO
                Base.show(stderr, ex)
            end
            nothing
        end
    end
end

precompile(transpile_tess_shader, (TranspilationSource, Dict{NodeHandle,DataType}))

macro callback_helper(fn::Expr)
    @assert MacroTools.isdef(fn) "@callback_helper placed before non-function AST node"

    global implicitApp
    implicitApp !== nothing && push!(implicitApp._callback_helpers, fn)

    return esc(fn)
end

export @callback_helper
