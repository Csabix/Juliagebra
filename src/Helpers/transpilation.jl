# identifiers used in generated tessellation shaders
const GPU_TESS_N = :JG_TESS_N
const GPU_TESS_N_STR = string(GPU_TESS_N)
const GPU_TESS_POS_BUF = :JG_TESS_POS_BUFFER
const GPU_TESS_POS_ARR = :JG_TESS_POS_ARRAY
const GPU_TESS_CB = :JG_TESS_CALLBACK
const GPU_TESS_ID = :JG_TESS_ID

# ! TODO: remove
const GPU_TESS_DEBUG_ARG = "--debug-gpu-tess"
const GPU_TESS_LOCAL_SIZE = UInt32(256)
const GPU_TESS_POS_BINDING_IDX = 0

_parse_curly(T::DataType)::Union{Expr,Symbol} = 
    isempty(T.parameters) ? nameof(T) : Expr(:curly, nameof(T), _parse_curly.(T.parameters)...)
_parse_curly(::Type{<:SMatrix{N,M,T}}) where {N,M,T} = :(MatNxMT{$N,$M,$(_parse_curly(T))})

# helper for base transpilation decorators reusable across pipelines
function try_transpile_tess_shader_base(callback_ast::Expr, dependent_bindings::Dict{Symbol, Tuple{NodeHandle, DataType}},
                                        extraUniforms::Vector{Tuple{String,DataType}}=Tuple{String,DataType}[])::Union{ShaderProgram,Nothing}
    global implicitApp
    # this is an internal error, not a transpilation failure
    implicitApp === nothing && error("Trying to invoke shader transpilation before implicitApp has been initialized")

    dbg::Bool = GPU_TESS_DEBUG_ARG in ARGS

    if !_is_normalized_callback(callback_ast)
        dbg && @log "AST provided as a callback is not of normalized callback form" INFO
        return nothing
    end

    translation_unit = Expr(:block)
    top_cmpd = translation_unit.args

    push!(top_cmpd, :(
        @gl_buffer @gl_restrict @gl_writeonly @gl_layout(
            std430, binding = $GPU_TESS_POS_BINDING_IDX,
            struct $GPU_TESS_POS_BUF
                $(GPU_TESS_POS_ARR)::Vector{Vec4}
            end
        ))
    )

    push!(top_cmpd, :(@gl_uniform global $GPU_TESS_N::UInt32))

    for (uni_name, uni_ty) in extraUniforms
        push!(top_cmpd, :(@gl_uniform global $(Symbol(uni_name))::$(_parse_curly(uni_ty))))
    end

    for (sym, (_, uni_type)) in dependent_bindings
        push!(top_cmpd, :(@gl_uniform global $sym::$(_parse_curly(uni_type))))
    end

    append!(top_cmpd, implicitApp._callback_helpers)

    # only the body is carried over: the callback's own arguments are dropped and recomputed
    # from GPU_TESS_ID by the caller, and an explicit return type, if any, is overwritten
    push!(top_cmpd, Expr(:function, :($GPU_TESS_CB($GPU_TESS_ID::UInt32)::Vec3F), callback_ast.args[2]))

    main_body = Expr(:block,
        :($GPU_TESS_ID = gl_GlobalInvocationID[:x]),
        :(
            if $GPU_TESS_ID >= $GPU_TESS_N
                return
            end
        ),
        :($GPU_TESS_POS_ARR[$GPU_TESS_ID + UInt32(1)] = Vec4F(JG_TESS_CALLBACK($GPU_TESS_ID), 0))
    )

    push!(top_cmpd, Expr(:function, :(main()::Nothing), main_body))

    cfg = implicitApp._transpiler_cfg

    if dbg
        println("code passed to transpiler:")
        println(translation_unit)
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
            sp = ShaderProgram([path], [GPU_TESS_N_STR, first.(extraUniforms)..., string.(collect(keys(dependent_bindings)))...])

            if sp.id != GLuint(0)
                sp
            else
                dbg && @log "couldn't create ShaderProgram from generated code"
                nothing
            end
        catch ex
            if dbg
                @log "error thrown while creating ShaderProgram from generated code, exception printed to stderr" INFO
                println(stderr, ex)
            end

            nothing
        end
    end
end

precompile(try_transpile_tess_shader_base, (Expr, Dict{Symbol,NodeHandle}, Vector{Tuple{String,DataType}}))

macro callback_helper(fn::Expr)
    @assert MacroTools.isdef(fn) "@callback_helper placed before non-function AST node"

    global implicitApp
    implicitApp !== nothing && push!(implicitApp._callback_helpers, fn)

    return esc(fn)
end

export @callback_helper
