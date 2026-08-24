# identifiers used in generated tessellation shaders
const GPU_TESS_N = :JG_TESS_N
const GPU_TESS_N_STR = string(GPU_TESS_N)
const GPU_TESS_POS_BUF = :JG_TESS_POS_BUFFER
const GPU_TESS_POS_ARR = :JG_TESS_POS_ARRAY
const GPU_TESS_CB = :JG_TESS_CALLBACK
const GPU_TESS_ID = :JG_TESS_ID

_parse_curly(T::DataType)::Union{Expr,Symbol} = 
        isempty(T.parameters) ? nameof(T) : Expr(:curly, nameof(T), _parse_curly.(T.parameters)...)

# helper for base transpilation decorators reusable across pipelines
function try_transpile_tess_shader_base(callback_ast::Expr, dependent_bindings::Dict{Symbol, <:DependentDNA},
                                        extraUniforms::Vector{Tuple{String,DataType}}=Tuple{String,DataType}[])::Union{ShaderProgram,Nothing}
    @time_cpu_begin GPUTessSetup CodeGen WrapperCodeGen

    # since we can gratefully fall back to CPU callbacks if transpilation fails,
    # we only log errors if explicitly requested (and as INFO), to avoid spamming the console
    dbg::Bool = GPU_TESS_DEBUG_ARG in ARGS

    if !isdef(callback_ast)
        dbg && @log "non-function definition provided as callback" INFO
        return nothing
    end

    translation_unit = Expr(:block)
    top_cmpd = translation_unit.args

    push!(top_cmpd, :(
        @gl_buffer @gl_restrict @gl_writeonly @gl_layout(
            std430, binding = $GPU_TESS_POS_BINDING_IDX,
            struct $GPU_TESS_POS_BUF
                $(GPU_TESS_POS_ARR)::Vector{Vec3}
            end
        ))
    )

    push!(top_cmpd, :(@gl_uniform global $GPU_TESS_N::UInt32))

    for (uni_name, UniTy) in extraUniforms
        type_expr = _parse_curly(UniTy)

        push!(top_cmpd, :(@gl_uniform global $(Symbol(uni_name))::$type_expr))
    end

    for (sym, dep) in dependent_bindings
        glsl_t = get_glsl_representation(typeof(dep))
        if glsl_t == Nothing
            dbg && @log "couldn't get GLSL representation for dependent type: $(typeof(dep))" INFO
        end

        glsl_t_expr = _parse_curly(glsl_t)
        push!(top_cmpd, :(@gl_uniform global $sym::$glsl_t_expr))
    end

    global implicitApp
    implicitApp !== nothing && append!(top_cmpd, implicitApp._cb_helper_asts)

    fn_data::Dict{Symbol,Any} = splitdef(callback_ast)

    fn_data[:name] = GPU_TESS_CB

    # if fn has explicit return type, it's currently overwritten
    fn_data[:rtype] = :Vec3F

    # args, kwargs and whereparams are stripped manually for now
    fn_data[:kwargs] = []
    fn_data[:whereparams] = ()
    delete!(fn_data, :params) # old Julia type param syntax

    fn_data[:args] = [:($GPU_TESS_ID::UInt32)]

    push!(top_cmpd, combinedef(fn_data))

    main_body = Expr(:block,
        :($GPU_TESS_ID = gl_GlobalInvocationID[:x]),
        :(
            if $GPU_TESS_ID >= $GPU_TESS_N
                return
            end
        ),
        :($GPU_TESS_POS_ARR[$GPU_TESS_ID + UInt32(1)] = JG_TESS_CALLBACK($GPU_TESS_ID))
    )

    main_fn = combinedef(
        Dict(
            :name => :main,
            :args => Any[],
            :kwargs => Any[],
            :whereparams => (),
            :rtype => :Nothing,
            :body => main_body
        )
    )

    push!(top_cmpd, main_fn)

    @time_cpu_end GPUTessSetup CodeGen WrapperCodeGen

    @time_cpu_begin GPUTessSetup CodeGen Transpilation

    cfg = implicitApp._transpiler_config

    if dbg
        println("code passed to transpiler:")
        println(translation_unit)
    end

    pipe = Pipe()
    glsl_code::Union{String,Nothing} =
        try
            redirect_stderr(pipe) do
                transpile(translation_unit; run_benchmarks=dbg, cfg)
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
    @time_cpu_end GPUTessSetup CodeGen Transpilation

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

    @time_cpu_begin GPUTessSetup CodeGen ShaderCreation
    # creates unique file in default temp directory
    path = tempname() * ".comp"
    sp = open(path, "w") do io
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
    @time_cpu_end GPUTessSetup CodeGen ShaderCreation

    return sp
end

precompile(try_transpile_tess_shader_base, (Expr,Dict{Symbol, <:DependentDNA},Vector{Tuple{String,DataType}}))

macro callback_helper(fn::Expr)
    @assert isdef(fn) "@callback_helper placed before non-function AST node"

    global implicitApp
    implicitApp !== nothing && push!(implicitApp._cb_helper_asts, fn)

    return esc(fn)
end

export @callback_helper
