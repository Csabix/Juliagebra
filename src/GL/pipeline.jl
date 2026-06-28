using StaticArrays, ModernGL
using glslang_jll: glslangValidator

const _shader_src_folder::String  = pkgdir(@__MODULE__,"assets","shaders","src")
const _shader_spirv_folder::String = pkgdir(@__MODULE__,"assets","shaders","spirv")

function _get_spirv_path(path::String)::String
    if isempty(path) return "" end
    path_parts = splitpath(path)
    src_index = findlast(x -> x == "src", path_parts)
    if isnothing(src_index)
        error("Give full path and the shader needs to be in $_shader_src_folder")
    end
    
    base_name, ext = splitext(path_parts[end])
    clean_ext = lstrip(ext, '.')
    
    path_parts[src_index] = "spirv"
    path_parts[end] = "$(base_name)_$(clean_ext).spv"
    return joinpath(path_parts)
end

struct ShaderGLSL
    path::String
    spirv_path::String
    function ShaderGLSL(path::String)
        path = normpath(path)
        spirv_path = _get_spirv_path(path)
        return new(path, spirv_path)
    end
    ShaderGLSL() = new("","")
end

macro spv_str(path::String)
    return ShaderGLSL(joinpath(_shader_src_folder, normpath(path)))
end

const glsl_shader_extensions::NTuple{14,String} = (
    "vert","tesc","tese","geom","frag",
    "comp",
    "mesh","task",
    "rgen","rint","rahit","rchit","rmiss","rcall"
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
    dependencies::Dict{String,Dict{String,Int}}
    spirv_extensions::Set{String}

    function PipelineLoader()
        pipelines::Vector{GLuint} = Vector{GLuint}()
        pipeline_sources::Vector{Vector{ShaderData}} = Vector{Vector{ShaderData}}()
        needs_reload::Set{Int} = Set{Int}()
        dependencies::Dict{String,Dict{String,Int}} = Dict{String,Dict{String,Int}}()
        spirv_extensions = Set{String}()
        
        num_spirv_extensions = GLint[0]
        glGetIntegerv(GL_NUM_SPIR_V_EXTENSIONS, num_spirv_extensions)
        for i in 1:num_spirv_extensions[1]
            push!(spirv_extensions, unsafe_string(glGetStringi(GL_SPIR_V_EXTENSIONS, i-1)))
        end

        return new(pipelines,pipeline_sources,needs_reload,dependencies,spirv_extensions)
    end
end

const PipelineHandle::DataType = UInt32
mutable struct Pipeline
    # For setting OpenGL states, blend, cull, etc. 
    set_state::Union{Nothing,Function}
    unset_state::Union{Nothing,Function}

    pipeline_handle::PipelineHandle
    loader::PipelineLoader
end

function activate(pipeline::Pipeline)::Nothing
    if !isnothing(pipeline.set_state) pipeline.set_state() end
    glUseProgram(pipeline.loader.pipelines[pipeline.pipeline_handle])
    return nothing
end

function deactivate(pipeline::Pipeline)::Nothing
    if !isnothing(pipeline.unset_state) pipeline.unset_state() end
    return nothing
end

function destroy!(pipeline::Pipeline)::Nothing
    pipeline.loader.pipelines[pipeline.pipeline_handle] = GLuint(0)
    pipeline.loader.pipeline_sources[pipeline.pipeline_handle] = ShaderData[]
    delete!(pipeline.loader.needs_reload,Int(pipeline.pipeline_handle))
    pipeline.pipeline_handle = PipelineHandle(0)
    pipeline.set_state = nothing
    pipeline.unset_state = nothing
    return nothing
end

function destroy!(loader::PipelineLoader)::Nothing
    foreach(loader.pipelines) do pipeline
        if pipeline != GLuint(0)
            glDeleteProgram(pipeline)
        end
    end
    empty!(loader.pipelines)
    empty!(loader.pipeline_sources)
    return nothing
end

function can_use_spirv(binary::Vector{UInt8},available_extensions::Set{String})::Bool
    words = reinterpret(UInt32, binary)
    is_little_edian = words[1] == 0x07230203
    index = 6
    while index < length(words)
        word = is_little_edian ? words[index] : bswap(words[index])
        word_count = word >> 16
        opcode = word & 0xFFFF
        if opcode == UInt32(17)
            index += word_count
            continue
        end
        if opcode == UInt32(10)
            extension_name = if is_little_edian
                ptr = pointer(words, index + 1)
                unsafe_string(convert(Ptr{UInt8}, ptr))
            else
                string_words = [bswap(words[i]) for i in (index + 1):(index + word_count - 1)]
                GC.@preserve string_words begin
                    unsafe_string(convert(Ptr{UInt8}, pointer(string_words)))
                end
            end
            index += word_count
            if !(extension_name in available_extensions) return false end
            continue
        end
        break
    end
    return true
end

function _resolve_includes(path::String, visited=String[])::String
    path = abspath(path)
    
    if path in visited
        cycle_path = join(visited_stack, "\n\t") * "\n\t" * path
        println("Circular dependency detected:\n$cycle_path")
        return ""
    end

    source::String = try
        read(path, String)
    catch _
        println("Failed to read file: $path")
        return ""
    end

    push!(visited, path)
    
    include_directive_pattern = r"#extension\s+GL_GOOGLE_include_directive\s*:\s*require"
    source = replace(source, include_directive_pattern => "")

    include_regex = r"#include\s+\"([^\"]+)\""
    source = replace(source, include_regex => function (m)
        inside_include = match(include_regex, m).captures[1]
        include_path = joinpath(dirname(path), inside_include)
        return _resolve_includes(include_path, visited)
    end)

    pop!(visited)

    return source
end

function _process_spec_constants(glsl_source::String, spec_constants::Dict{GLuint, GLuint})
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
                write(out, "const float $var_name = uintBitsToFloat($hex_str);")
            else
                write(out, "const $type_str $var_name = $val;")
            end
        else
            write(out, "const $type_str $var_name = $default_val;")
        end
        last_idx = m.offset + length(m.match)
    end
    write(out, SubString(glsl_source, last_idx))
    return String(take!(out))
end

function _shader(source::ShaderData,binary::Vector{UInt8},as_spirv::Bool)::GLuint
    shader::GLuint = GLuint(0)
    shader = glCreateShader(source.stage)
    if as_spirv
        glShaderBinary(1, [shader], 0x9551, binary, length(binary))
        if isnothing(source.spec_index) || isnothing(source.spec_value)
            glSpecializeShader(shader, "main", 0, C_NULL, C_NULL);
        else
            glSpecializeShader(shader, "main", length(source.spec_index), source.spec_index, source.spec_value);
        end
    else
        spec_mapping = Dict{GLuint,GLuint}()
        if !isnothing(source.spec_index) && !isnothing(source.spec_value)
            for (index, value) in zip(source.spec_index, source.spec_value)
                spec_mapping[index] = value
            end
        end
        glsl_source::String = _process_spec_constants(_resolve_includes(source.glsl_path), spec_mapping)
        GC.@preserve glsl_source begin
            glShaderSource(shader,1,Ref(pointer(glsl_source)), C_NULL)
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
        
        println("Failed to compile shader stage")
    end
    return shader
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
        push!(binaries,read(source.spirv_path))
    end
    as_spirv::Bool = all(binary -> can_use_spirv(binary,loader.spirv_extensions), binaries)
    
    shaders = Vector{GLuint}()
    sizehint!(shaders, 6)

    if as_spirv
        for (source,binary) in zip(sources,binaries)
            push!(shaders, _shader(source,binary,true))
        end
    else
        for (source,binary) in zip(sources,binaries)
            push!(shaders, _shader(source,binary,false))
        end
    end

    loader.pipelines[index] = _link_shaders(shaders)

    return nothing
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
        glGetProgramInfoLog(prog,infoLogLength[],C_NULL,infoLog)
        
        errorMessage = String(infoLog)
        println(errorMessage)

        glDeleteProgram(prog)
        prog = GLuint(0)

        println("Program linking failed")
    end
    return prog
end

function _parse_stage_data(stage::GLuint, stage_data::ShaderGLSL)::ShaderData
    return ShaderData(stage,stage_data.spirv_path,nothing,nothing,stage_data.path)
end
function _parse_stage_data(stage::GLuint, stage_data::Tuple{ShaderGLSL,Vector{Tuple{GLuint,GLuint}}})::ShaderData
    locs = GLuint[]
    vals = GLuint[]
    for (loc,val) in stage_data[2]
        push!(locs,loc)
        push!(vals,val)
    end
    return ShaderData(stage,stage_data[1].spirv_path,locs,vals,stage_data[1].path)
end

function _insert_shader_data(loader::PipelineLoader, shader_data::Vector{ShaderData})::PipelineHandle
    empty_slot = findfirst(isempty, loader.pipeline_sources)
    if empty_slot === nothing
        push!(loader.pipeline_sources, shader_data)
        push!(loader.pipelines, GLuint(0))
        return PipelineHandle(length(loader.pipeline_sources))
    else
        loader.pipeline_sources[empty_slot] = shader_data
        return PipelineHandle(empty_slot)
    end
end

function create_graphics_pipeline!(loader::PipelineLoader;
    vert::Union{Nothing, ShaderGLSL, Tuple{ShaderGLSL,Vector{Tuple{GLuint,GLuint}}}} = nothing,
    tesc::Union{Nothing, ShaderGLSL, Tuple{ShaderGLSL,Vector{Tuple{GLuint,GLuint}}}} = nothing,
    tese::Union{Nothing, ShaderGLSL, Tuple{ShaderGLSL,Vector{Tuple{GLuint,GLuint}}}} = nothing,
    geom::Union{Nothing, ShaderGLSL, Tuple{ShaderGLSL,Vector{Tuple{GLuint,GLuint}}}} = nothing,
    frag::Union{Nothing, ShaderGLSL, Tuple{ShaderGLSL,Vector{Tuple{GLuint,GLuint}}}} = nothing)::Pipeline

    shader_data::Vector{ShaderData} = ShaderData[]
    if vert !== nothing push!(shader_data,_parse_stage_data(GL_VERTEX_SHADER,vert)) end
    if tesc !== nothing push!(shader_data,_parse_stage_data(GL_TESS_CONTROL_SHADER,tesc)) end
    if tese !== nothing push!(shader_data,_parse_stage_data(GL_TESS_EVALUATION_SHADER,tese)) end
    if geom !== nothing push!(shader_data,_parse_stage_data(GL_GEOMETRY_SHADER,geom)) end
    if frag !== nothing push!(shader_data,_parse_stage_data(GL_FRAGMENT_SHADER,frag)) end

    handle::PipelineHandle = _insert_shader_data(loader, shader_data)
    _compile(loader, handle)

    return Pipeline(nothing, nothing, handle, loader)
end

function create_compute_pipeline!(loader::PipelineLoader, comp::Union{ShaderGLSL, Tuple{ShaderGLSL,Vector{Tuple{GLuint,GLuint}}}})::Pipeline
    shader_data::Vector{ShaderData} = ShaderData[_parse_stage_data(GL_COMPUTE_SHADER,comp)]

    handle::PipelineHandle = _insert_shader_data(loader, shader_data)
    _compile(loader, handle)

    return Pipeline(nothing, nothing, handle, loader)
end

function update!(loader::PipelineLoader)::Bool
    shader_reload = !isempty(loader.needs_reload)
    for i in loader.needs_reload
        _compile(loader,i)
    end
    empty!(loader.needs_reload)
    return shader_reload
end

function get_glsl_delete_callback(loader::PipelineLoader)::Function
    return (path::String) -> begin
        shader_path = ShaderGLSL(path)
        if isfile(shader_path.spirv_path)
            rm(shader_path.spirv_path)
        end
        for (_,dependencies) in loader.dependencies
            if haskey(dependencies, shader_path.path)
                old_ref_count = dependencies[shader_path.path]
                dependencies[shader_path.path] = old_ref_count - 1
                if old_ref_count == 1
                    delete!(dependencies, shader_path.path)
                end
            end
        end
        return nothing
    end
end

function get_glsl_include_update_callback(loader::PipelineLoader)::Function
    return (path::String) -> begin
        if haskey(loader.dependencies,path)
            for dependent in keys(loader.dependencies[path])
                _glsl_update_callback(loader,dependent)
            end
        end
        return nothing
    end
end

function get_glsl_update_callback(loader::PipelineLoader)::Function
    return (path::String) -> begin
        return _glsl_update_callback(loader,path)
    end
end

function _glsl_update_callback(loader::PipelineLoader,path::String)::Nothing
    shader = ShaderGLSL(path)
    _to_spirv(loader,shader)
    for i in eachindex(loader.pipeline_sources)
        if any(stage -> stage.spirv_path == shader.spirv_path, loader.pipeline_sources[i])
            push!(loader.needs_reload,i)
        end
    end
    return nothing
end

function _to_spirv(loader::PipelineLoader, shader::ShaderGLSL)::Nothing
    glslang = glslangValidator(identity)
    path = normpath(shader.path)
    output_path = shader.spirv_path

    output_dir = dirname(output_path)
    mkpath(output_dir)

    for dependencies in values(loader.dependencies)
        if haskey(dependencies, path)
            old_ref_count = dependencies[path]
            dependencies[path] = old_ref_count - 1
            if old_ref_count == 1
                delete!(dependencies, path)
            end
        end
    end
    
    try
        mktemp() do depfile_path, depfile_io
            run(`$glslang -G $path -o $output_path --depfile $depfile_path`)
            
            content = read(depfile_path, String)
            
            parts = split(content, ' ', limit=2)
            if length(parts) == 2
                dep_entries = split(parts[2])
                for dep in dep_entries
                    dep_abs = normpath(replace(replace(dep, "\\:" => ":"), "\\\\" => "/"))
                    if dep_abs != path && isfile(dep_abs)
                        if haskey(loader.dependencies,dep_abs)
                            if haskey(loader.dependencies[dep_abs],path)
                                loader.dependencies[dep_abs][path] = loader.dependencies[dep_abs][path] + 1
                            else
                                loader.dependencies[dep_abs][path] = 1
                            end
                        else
                            loader.dependencies[dep_abs] = Dict{String,Int}(path => 1)
                        end
                    end
                end
            end
        end
    catch e
        @warn "Compilation or dependency tracking failed: $e"
    end
    return nothing
end

function _has_files(folder::String)
    !isdir(folder) && return false
    for (root, dirs, files) in walkdir(folder)
        if !isempty(files)
            return true
        end
    end
    return false
end

function full_compile(loader::PipelineLoader)::Nothing
    # Compile if JULIAGEBRA_COMPILE_SPIRV is true or spirv folder doesnt exists or empty
    if !(haskey(ENV,"JULIAGEBRA_COMPILE_SPIRV") &&
        ENV["JULIAGEBRA_COMPILE_SPIRV"] == "true" ||
        !_has_files(_shader_spirv_folder))
        return nothing
    end

    delete_spv = Set{String}()
    if isdir(_shader_spirv_folder)
        for (root, _, files) in walkdir(_shader_spirv_folder)
            for file in files
                push!(delete_spv,joinpath(root,file))
            end
        end
    end

    for (root, _, files) in walkdir(_shader_src_folder)
        for file in files
            _, ext = splitext(file)
            ext = lstrip(ext, '.')
            if ext in glsl_shader_extensions
                path = joinpath(root, file)
                shader = ShaderGLSL(path)
                delete!(delete_spv,shader.spirv_path)
                _to_spirv(loader, shader)
            end
        end
    end

    for unused_spv in delete_spv
        rm(unused_spv)
    end

    return nothing
end