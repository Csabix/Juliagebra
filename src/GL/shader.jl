const _SHADER_FOLDER::String = joinpath(pkgdir(@__MODULE__),"src","Shaders")
const _possible_types = Union{String,Tuple{String,Vector{String}},Tuple{String,Vector{Pair{String,String}}},Tuple{String,Vector{String},Vector{Pair{String,String}}}}

struct ShaderProgram
    id::GLuint
    uniforms::Dict{String,GLint}

    function ShaderProgram(
        shader_stages,
        uniform_names::Vector{String}=Vector{String}(undef,0))

        stages = @MVector [GLuint(0) for i = 1:5]
        for (i,stage::_possible_types) in enumerate(shader_stages)
            (path,defines,replacements) = parse_stage(stage)
            source = read_shader_stage(path, defines, replacements)
            stages[i] = create_shader_stage(path, source)
        end

        prog = link_shaders(stages)
        if prog == GLuint(0)
            return new(zero(GLuint), Dict{String,GLint}())
        end
        uniforms = scrape_uniforms(prog, uniform_names)
        return new(prog, uniforms)
    end
end
destroy!(self::ShaderProgram) = (self.id!=0 && glDeleteProgram(self.id))
activate(self::ShaderProgram) = glUseProgram(self.id)

function uniform(self::ShaderProgram,name::String,data)::Nothing
    if self.id == GLuint(0) return nothing end
    if !haskey(self.uniforms,name)
        println("No Uniform named: $name")
        return nothing
    end
    glUniform(self.uniforms[name],data)
end

function parse_stage(stage::String)::Tuple{String,Union{Nothing,Vector{String}},Union{Nothing,Vector{Pair{String,String}}}}
    return stage,nothing,nothing
end
function parse_stage(stage::Tuple{String,Vector{String}})::Tuple{String,Union{Nothing,Vector{String}},Union{Nothing,Vector{Pair{String,String}}}}
    return stage[1],stage[2],nothing
end
function parse_stage(stage::Tuple{String,Vector{Pair{String,String}}})::Tuple{String,Union{Nothing,Vector{String}},Union{Nothing,Vector{Pair{String,String}}}}
    return stage[1],nothing,stage[2]
end
function parse_stage(stage::Tuple{String,Vector{String},Vector{Pair{String,String}}})::Tuple{String,Union{Nothing,Vector{String}},Union{Nothing,Vector{Pair{String,String}}}}
    return stage[1],stage[2],stage[3]
end

function read_shader_stage(
    path::String,
    defines::Union{Nothing,Vector{String}},
    replacements::Union{Nothing,Vector{Pair{String,String}}})::Union{Nothing,String}
    path = joinpath(_SHADER_FOLDER, path)
    
    source::String = resolve_includes(path)

    if !isnothing(defines)
        version_match = match(r"#version.*\n", source)
        if !isnothing(version_match)
            header = version_match.match
            body = source[version_match.offset + length(version_match.match):end]
            define_block = join(["#define $d" for d in defines], "\n") * "\n"
            source = header * define_block * body
        end
    end

    if !isnothing(replacements)
        for replacement in replacements
            source = replace(source, replacement)
        end
    end
    return source
end

function resolve_includes(path::String, visited=String[])::String
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
    
    include_regex = r"#include\s+\"([^\"]+)\""
    source = replace(source, include_regex => function (m)
        inside_include = match(include_regex, m).captures[1]
        include_path = joinpath(dirname(path), inside_include)
        return resolve_includes(include_path, visited)
    end)

    pop!(visited)

    return source
end

macro s4(s)
    return :(tuple($(codeunits(s)...)))
end

const _SHADER_EXTENSIONS = SVector{6, Tuple{NTuple{4, UInt8}, GLuint}}((
    (@s4("comp"), GL_COMPUTE_SHADER),
    (@s4("vert"), GL_VERTEX_SHADER),
    (@s4("tesc"), GL_TESS_CONTROL_SHADER),
    (@s4("tese"), GL_TESS_EVALUATION_SHADER),
    (@s4("geom"), GL_GEOMETRY_SHADER),
    (@s4("frag"), GL_FRAGMENT_SHADER)
))

function get_shader_type(path::String)::GLuint
    extension_index = findlast(==('.'), path)
    if isnothing(extension_index) || extension_index + 4 != length(path)
        println("Invalid shader path: $path")
        return zero(GLuint)
    end

    units = codeunits(view(path,extension_index+1:length(path)))
    path_ext = (units[1],units[2],units[3],units[4])

    for (ext,type) in _SHADER_EXTENSIONS
        if ext == path_ext
            return type
        end
    end
    
    println("Invalid shader path: $path")
    return zero(GLuint)
end

function create_shader_stage(path::String, source::String)::GLuint
    stage::GLuint = get_shader_type(path)
    if stage == zero(GLuint)
        println("Failed to create shader stage: $path")
        return zero(GLuint)
    end

    shader = glCreateShader(stage)
    GC.@preserve source begin
        glShaderSource(shader,1,Ref(pointer(source)), C_NULL)
    end
    glCompileShader(shader)

    status = Ref{GLint}(0)
    glGetShaderiv(shader, GL_COMPILE_STATUS, status)
    if status[] == GL_FALSE
        infoLogLength = Ref{GLint}(0)
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, infoLogLength)
        
        infoLog = Vector{UInt8}(undef, infoLogLength[])
        glGetShaderInfoLog(shader,infoLogLength[],C_NULL,infoLog)
        
        errorMessage = String(infoLog)
        println(errorMessage)

        glDeleteShader(shader)
        
        println("Failed to compile shader stage: $path")
        return zero(GLuint)
    end
    return shader
end

function link_shaders(shaders::MVector{5, GLuint})::GLuint
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

        println("Program linking failed")
        return GLuint(0)
    end
    return prog
end

function scrape_uniforms(prog::GLuint, names::Vector{String})::Dict{String,GLint}
    namesToLocations = Dict{String,GLint}()
    for name in names
        location = glGetUniformLocation(prog,name)
        if location == -1
            println("No uniform named: $name")
            continue
        end
        namesToLocations[name] = location
    end
    return namesToLocations
end