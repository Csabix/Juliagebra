using StaticArrays, ModernGL, Scratch, Serialization
using glslang_jll: glslangValidator

function create_shader_folder()
    scratch = @get_scratch!("shaders")
    return scratch
end

const _shader_src_folder::String = pkgdir(@__MODULE__, "assets", "shaders", "src")
const _shader_folder::String = create_shader_folder()
const _shader_glsl_folder::String = joinpath(_shader_folder, "glsl")
const _shader_spirv_folder::String = joinpath(_shader_folder, "spirv")

_glsl_output_file(src_path::String)::String = joinpath(_shader_glsl_folder, relpath(src_path, _shader_src_folder))
_spirv_output_file(src_path::String)::String = joinpath(_shader_spirv_folder, "$(relpath(src_path, _shader_src_folder)).spv")

struct ShaderGLSL
    path::String
    spirv_path::String
    function ShaderGLSL(path::String)
        @assert isabspath(path)
        return new(
            _glsl_output_file(path),
            _spirv_output_file(path)
        )
    end
    ShaderGLSL() = new("", "")
end

macro spv_str(path::String)
    return ShaderGLSL(joinpath(_shader_src_folder, normpath(path)))
end

const glsl_shader_extensions::NTuple{14,String} = (
    "vert", "tesc", "tese", "geom", "frag",
    "comp",
    "mesh", "task",
    "rgen", "rint", "rahit", "rchit", "rmiss", "rcall"
)
const glsl_shader_include_extensions::NTuple{1,String} = ("glsl",)

struct ShaderData
    stage::GLuint
    spirv_path::String
    spec_index::Union{Vector{GLuint},Nothing}
    spec_value::Union{Vector{GLuint},Nothing}
    glsl_path::String
end

struct PipelineLoader
    pipelines::Vector{GLuint}
    pipeline_sources::Vector{Vector{ShaderData}}
    needs_reload::Set{Int}
    dependencies::Dict{String,Set{String}}
    spirv_extensions::Set{String}

    function PipelineLoader()
        pipelines = Vector{GLuint}()
        pipeline_sources = Vector{Vector{ShaderData}}()
        needs_reload = Set{Int}()
        dependencies = Dict{String,Set{String}}()
        spirv_extensions = Set{String}()

        num_spirv_extensions = Ref{GLint}(0)
        glGetIntegerv(GL_NUM_SPIR_V_EXTENSIONS, num_spirv_extensions)
        for i in 1:num_spirv_extensions[]
            push!(spirv_extensions, unsafe_string(glGetStringi(GL_SPIR_V_EXTENSIONS, i-1)))
        end

        return new(pipelines, pipeline_sources, needs_reload, dependencies, spirv_extensions)
    end
end

const PipelineHandle::DataType = UInt32
mutable struct Pipeline
    set_state::Union{Nothing,Function}
    unset_state::Union{Nothing,Function}

    pipeline_handle::PipelineHandle
    loader::PipelineLoader
end

function activate(pipeline::Pipeline)::Nothing
    if !isnothing(pipeline.set_state)
        pipeline.set_state()
    end
    glUseProgram(pipeline.loader.pipelines[pipeline.pipeline_handle])
    return nothing
end

function deactivate(pipeline::Pipeline)::Nothing
    if !isnothing(pipeline.unset_state)
        pipeline.unset_state()
    end
    return nothing
end

function destroy!(pipeline::Pipeline)::Nothing
    pipeline.loader.pipelines[pipeline.pipeline_handle] = GLuint(0)
    pipeline.loader.pipeline_sources[pipeline.pipeline_handle] = ShaderData[]
    delete!(pipeline.loader.needs_reload, Int(pipeline.pipeline_handle))
    pipeline.pipeline_handle = PipelineHandle(0)
    pipeline.set_state = nothing
    pipeline.unset_state = nothing
    return nothing
end

function destroy!(loader::PipelineLoader)::Nothing
    for pipeline in loader.pipelines
        if pipeline != GLuint(0)
            glDeleteProgram(pipeline)
        end
    end
    empty!(loader.pipelines)
    empty!(loader.pipeline_sources)
    empty!(loader.needs_reload)
    empty!(loader.dependencies)
    return nothing
end

function _resolve_includes(path::String, visited, included_files)::Tuple{String,Set{String}}
    if path in visited
        cycle_path = join(visited, "\n\t") * "\n\t" * path
        println("Circular dependency detected:\n\t$cycle_path")
        empty!(included_files)
        return ("", included_files)
    end

    source::String = try
        read(path, String)
    catch _
        println("Failed to read file: $path")
        empty!(included_files)
        return ("", included_files)
    end

    push!(included_files, path)
    push!(visited, path)

    include_directive_pattern = r"#extension\s+GL_GOOGLE_include_directive\s*:\s*require"
    source = replace(source, include_directive_pattern => "")

    include_regex = r"#include\s+\"([^\"]+)\""
    source = replace(source, include_regex => function (m)
        inside_include = match(include_regex, m).captures[1]
        include_path = normpath(joinpath(dirname(path), inside_include))
        resolved_content, _ = _resolve_includes(include_path, visited, included_files)
        return resolved_content
    end)

    pop!(visited)

    return (source, included_files)
end

function _resolve_includes(path::String)::Tuple{String,Set{String}}
    @assert isabspath(path)
    source, visited = _resolve_includes(path, String[], Set{String}())
    delete!(visited, path)
    return source, visited
end

function can_use_spirv(binary::Vector{UInt8}, available_extensions::Set{String})::Bool
    words = reinterpret(UInt32, binary)
    if isempty(words)
        return false
    end
    is_little_endian = words[1] == 0x07230203
    index = 6
    while index <= length(words)
        word = is_little_endian ? words[index] : bswap(words[index])
        word_count = word >> 16
        if word_count == 0
            return false
        end
        opcode = word & 0xFFFF
        if opcode == UInt32(17) # OpSourceExtension
            index += word_count
            continue
        end
        if opcode == UInt32(10) # OpExtension
            extension_name = if is_little_endian
                ptr = pointer(words, index + 1)
                unsafe_string(convert(Ptr{UInt8}, ptr))
            else
                string_words = [bswap(words[i]) for i in (index+1):(index+word_count-1)]
                GC.@preserve string_words begin
                    unsafe_string(convert(Ptr{UInt8}, pointer(string_words)))
                end
            end
            index += word_count
            if !(extension_name in available_extensions)
                return false
            end
            continue
        end
        break
    end
    return true
end

function _process_spec_constants(glsl_source::String, spec_constants::Dict{GLuint,GLuint})
    pattern = r"layout\s*\(\s*constant_id\s*=\s*(\d+)\s*\)\s*const\s+(\w+)\s+(\w+)\s*=\s*([^;]+);"

    out = IOBuffer()
    last_idx = 1

    for m in eachmatch(pattern, glsl_source)
        write(out, SubString(glsl_source, last_idx, prevind(glsl_source, m.offset)))

        id = parse(GLuint, m.captures[1])
        type_str = m.captures[2]
        var_name = m.captures[3]
        default_val = strip(m.captures[4])

        if haskey(spec_constants, id)
            val = spec_constants[id]
            if type_str == "float"
                hex_str = "0x" * string(val, base=16) * "u"
                write(out, "float $var_name = uintBitsToFloat($hex_str);")
            else
                write(out, "$type_str $var_name = $type_str($val);")
            end
        else
            write(out, "$type_str $var_name = $default_val;")
        end
        last_idx = m.offset + length(m.match)
    end
    write(out, SubString(glsl_source, last_idx))
    return String(take!(out))
end

function _shader(source::ShaderData, binary::Vector{UInt8}, as_spirv::Bool)::GLuint
    shader::GLuint = glCreateShader(source.stage)
    if as_spirv
        glShaderBinary(1, [shader], 0x9551, binary, length(binary))
        if isnothing(source.spec_index) || isnothing(source.spec_value)
            glSpecializeShader(shader, "main", 0, C_NULL, C_NULL)
        else
            glSpecializeShader(shader, "main", length(source.spec_index), source.spec_index, source.spec_value)
        end
    else
        spec_mapping = Dict{GLuint,GLuint}()
        if !isnothing(source.spec_index) && !isnothing(source.spec_value)
            for (index, value) in zip(source.spec_index, source.spec_value)
                spec_mapping[index] = value
            end
        end
        glsl_source::String = try
            read(source.glsl_path, String)
        catch _
            return shader
        end
        glsl_source = _process_spec_constants(glsl_source, spec_mapping)
        GC.@preserve glsl_source begin
            glShaderSource(shader, 1, Ref(pointer(glsl_source)), C_NULL)
        end
        glCompileShader(shader)
    end

    status = Ref{GLint}(0)
    glGetShaderiv(shader, GL_COMPILE_STATUS, status)
    if status[] == GL_FALSE
        infoLogLength = Ref{GLint}(0)
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, infoLogLength)

        infoLog = Vector{UInt8}(undef, infoLogLength[])
        glGetShaderInfoLog(shader, infoLogLength[], C_NULL, infoLog)

        errorMessage = String(infoLog)
        println(errorMessage)

        glDeleteShader(shader)
        shader = GLuint(0)

        println("Failed to compile shader stage $(source.glsl_path)")
    end
    return shader
end

function _link_shaders(shaders::Vector{GLuint})::GLuint
    prog = glCreateProgram()
    for shader in shaders
        if shader != GLuint(0)
            glAttachShader(prog, shader)
        end
    end

    glLinkProgram(prog)

    for shader in shaders
        if shader != GLuint(0)
            glDeleteShader(shader)
        end
    end

    status = Ref{GLint}(0)
    glGetProgramiv(prog, GL_LINK_STATUS, status)
    if status[] == GL_FALSE
        infoLogLength = Ref{GLint}(0)
        glGetProgramiv(prog, GL_INFO_LOG_LENGTH, infoLogLength)

        infoLog = Vector{UInt8}(undef, infoLogLength[])
        glGetProgramInfoLog(prog, infoLogLength[], C_NULL, infoLog)

        errorMessage = String(infoLog)
        println(errorMessage)

        glDeleteProgram(prog)
        prog = GLuint(0)

        println("Program linking failed")
    end
    return prog
end

function _compile(loader::PipelineLoader, index)::Nothing
    if loader.pipelines[index] != GLuint(0)
        glDeleteProgram(loader.pipelines[index])
        loader.pipelines[index] = GLuint(0)
    end

    sources = loader.pipeline_sources[index]
    if isempty(sources)
        return nothing
    end

    binaries = Vector{Vector{UInt8}}()
    sizehint!(binaries, 6)
    for source in sources
        push!(binaries, isfile(source.spirv_path) ? read(source.spirv_path) : UInt8[])
    end
    as_spirv::Bool = all(binary -> !isempty(binary) && can_use_spirv(binary, loader.spirv_extensions), binaries)

    shaders = Vector{GLuint}()
    sizehint!(shaders, 6)

    for (source, binary) in zip(sources, binaries)
        push!(shaders, _shader(source, binary, as_spirv))
    end

    loader.pipelines[index] = _link_shaders(shaders)

    return nothing
end

function _parse_stage_data(stage::GLuint, stage_data::ShaderGLSL)::ShaderData
    return ShaderData(stage, stage_data.spirv_path, nothing, nothing, stage_data.path)
end

function _parse_stage_data(stage::GLuint, stage_data::Tuple{ShaderGLSL,Vector{Tuple{GLuint,GLuint}}})::ShaderData
    locs = GLuint[]
    vals = GLuint[]
    for (loc, val) in stage_data[2]
        push!(locs, loc)
        push!(vals, val)
    end
    return ShaderData(stage, stage_data[1].spirv_path, locs, vals, stage_data[1].path)
end

function _insert_shader_data(loader::PipelineLoader, shader_data::Vector{ShaderData})::PipelineHandle
    empty_slot = findfirst(isempty, loader.pipeline_sources)
    if empty_slot === nothing
        push!(loader.pipeline_sources, shader_data)
        push!(loader.pipelines, GLuint(0))
        return PipelineHandle(length(loader.pipeline_sources))
    else
        loader.pipeline_sources[empty_slot] = shader_data
        loader.pipelines[empty_slot] = GLuint(0)
        return PipelineHandle(empty_slot)
    end
end

function create_graphics_pipeline!(loader::PipelineLoader;
    vert::Union{Nothing,ShaderGLSL,Tuple{ShaderGLSL,Vector{Tuple{GLuint,GLuint}}}}=nothing,
    tesc::Union{Nothing,ShaderGLSL,Tuple{ShaderGLSL,Vector{Tuple{GLuint,GLuint}}}}=nothing,
    tese::Union{Nothing,ShaderGLSL,Tuple{ShaderGLSL,Vector{Tuple{GLuint,GLuint}}}}=nothing,
    geom::Union{Nothing,ShaderGLSL,Tuple{ShaderGLSL,Vector{Tuple{GLuint,GLuint}}}}=nothing,
    frag::Union{Nothing,ShaderGLSL,Tuple{ShaderGLSL,Vector{Tuple{GLuint,GLuint}}}}=nothing)::Pipeline

    shader_data::Vector{ShaderData} = ShaderData[]
    if vert !== nothing
        push!(shader_data, _parse_stage_data(GL_VERTEX_SHADER, vert))
    end
    if tesc !== nothing
        push!(shader_data, _parse_stage_data(GL_TESS_CONTROL_SHADER, tesc))
    end
    if tese !== nothing
        push!(shader_data, _parse_stage_data(GL_TESS_EVALUATION_SHADER, tese))
    end
    if geom !== nothing
        push!(shader_data, _parse_stage_data(GL_GEOMETRY_SHADER, geom))
    end
    if frag !== nothing
        push!(shader_data, _parse_stage_data(GL_FRAGMENT_SHADER, frag))
    end

    handle::PipelineHandle = _insert_shader_data(loader, shader_data)
    _compile(loader, handle)

    return Pipeline(nothing, nothing, handle, loader)
end

function create_compute_pipeline!(loader::PipelineLoader, comp::Union{ShaderGLSL,Tuple{ShaderGLSL,Vector{Tuple{GLuint,GLuint}}}})::Pipeline
    shader_data::Vector{ShaderData} = ShaderData[_parse_stage_data(GL_COMPUTE_SHADER, comp)]

    handle::PipelineHandle = _insert_shader_data(loader, shader_data)
    _compile(loader, handle)

    return Pipeline(nothing, nothing, handle, loader)
end

function update!(loader::PipelineLoader)::Bool
    shader_reload = !isempty(loader.needs_reload)
    for i in loader.needs_reload
        _compile(loader, i)
    end
    empty!(loader.needs_reload)
    if shader_reload
        serialize(joinpath(_shader_glsl_folder, "dependencies.jls"), loader.dependencies)
    end
    return shader_reload
end

function _compile_glsl(path::String)::Set{String}
    @assert isabspath(path)
    _, ext = splitext(path)
    ext = lstrip(ext, '.')
    if ext in glsl_shader_extensions
        glsl_source::String, visited = _resolve_includes(path)
        output = _glsl_output_file(path)
        mkpath(dirname(output))
        write(output, glsl_source)
        return visited
    end
    return Set{String}()
end

function _compile_spirv(path::String)::Nothing
    @assert isabspath(path)
    _, ext = splitext(path)
    ext = lstrip(ext, '.')
    if ext in glsl_shader_extensions
        output = _spirv_output_file(path)
        mkpath(dirname(output))
        glslang = glslangValidator(identity)
        run(`$glslang -G $path -o $output`)
    end
    return nothing
end

function _remove_shader_dep(dependencies::Dict{String,Set{String}}, path::String)::Nothing
    for (_, deps) in dependencies
        delete!(deps, path)
    end
    filter!(deps -> !isempty(deps), dependencies)
    return nothing
end

function _add_shader_dep(dependencies::Dict{String,Set{String}}, path::String, visited::Set{String})::Nothing
    for dep in visited
        deps = get!(dependencies, dep, Set{String}())
        push!(deps, path)
    end
    return nothing
end

function _glsl_update_callback(loader::PipelineLoader, path::String)::Nothing
    _, ext = splitext(path)
    ext = lstrip(ext, '.')

    if ext in glsl_shader_include_extensions
        if haskey(loader.dependencies, path)
            for dependent in loader.dependencies[path]
                _glsl_update_callback(loader, dependent)
            end
        end
        return nothing
    elseif ext in glsl_shader_extensions
        spirv_path = _spirv_output_file(path)
        visited = _compile_glsl(path)
        _compile_spirv(path)
        _remove_shader_dep(loader.dependencies, path)
        _add_shader_dep(loader.dependencies, path, visited)

        for i in eachindex(loader.pipeline_sources)
            if any(stage -> stage.spirv_path == spirv_path, loader.pipeline_sources[i])
                push!(loader.needs_reload, i)
            end
        end
    end
    return nothing
end

function get_glsl_delete_callback(loader::PipelineLoader)::Function
    return (path::String) -> begin
        rm(_spirv_output_file(path); force=true)
        rm(_glsl_output_file(path); force=true)
        _remove_shader_dep(loader.dependencies, path)
        delete!(loader.dependencies, path)
        return nothing
    end
end

function get_glsl_update_callback(loader::PipelineLoader)::Function
    return (path::String) -> begin
        _glsl_update_callback(loader, normpath(abspath(path)))
    end
end

function _compile_shaders()::Bool
    dependencies_path = joinpath(_shader_glsl_folder, "dependencies.jls")
    recompile::Bool = false
    if !isdir(_shader_glsl_folder) || !isdir(_shader_spirv_folder) || !isfile(dependencies_path)
        recompile = true
    else
        last_compile_time = mtime(dependencies_path)
        for (root, _, files) in walkdir(_shader_src_folder)
            for file in files
                if mtime(joinpath(root, file)) > last_compile_time
                    recompile = true
                end
            end
        end
    end

    if recompile
        for item in readdir(_shader_folder, join=true)
            rm(item, recursive=true, force=true)
        end
        mkpath(_shader_glsl_folder)
        mkpath(_shader_spirv_folder)
    end
    return recompile
end

function compile_shaders(loader::PipelineLoader)::Nothing
    if !_compile_shaders()
        dependencies = deserialize(joinpath(_shader_glsl_folder, "dependencies.jls"))::Dict{String,Set{String}}
        for (k, v) in dependencies
            loader.dependencies[k] = v
        end
        return nothing
    end

    for (root, _, files) in walkdir(_shader_src_folder)
        for file in files
            input = joinpath(root, file)
            visited = _compile_glsl(input)
            _add_shader_dep(loader.dependencies, input, visited)
        end
    end
    serialize(joinpath(_shader_glsl_folder, "dependencies.jls"), loader.dependencies)

    paths = String[]
    for (root, _, files) in walkdir(_shader_src_folder)
        for file in files
            push!(paths,joinpath(root, file))
        end
    end
    Threads.@threads for path in paths
        _compile_spirv(path)
    end
    return nothing
end

function auto_compile_shaders(auto_compile::Bool)::Nothing
    ENV["AUTO_COMPILE_SHADER"] = auto_compile ? "true" : "false"
    return nothing
end

export auto_compile_shaders