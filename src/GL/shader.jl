const _SHADER_FOLDER::String = joinpath(pkgdir(@__MODULE__),"src","Shaders")

mutable struct ShaderProgram <: OpenGLWrapper
    _id::GLuint
    _uniforms::Dict{String,GLint}

    function ShaderProgram(shader_stage_paths::Vector{String},uniform_names::Vector{String}=Vector{String}(undef,0))
        if length(shader_stage_paths) > 5
            @log "Too many shader paths" ERR
            return new(GLuint(0),Dict{String,GLint}())
        end

        stages = @MVector [GLuint(0) for i = 1:5]
        for (i,shader_path) in enumerate(shader_stage_paths)
            stage = _create_shader_stage(joinpath(_SHADER_FOLDER,shader_path))
            if stage == GLuint(0)
                for stage in stages
                    if stage != GLuint(0)
                        glDeleteShader(stage)
                    end
                end
                @log "Failed to create shader program" ERR
                return new(GLuint(0),Dict{String,GLint}())
            end
            stages[i] = stage
        end

        prog = _link_shaders(stages)
        if prog == GLuint(0)
            return new(GLuint(0),Dict{String,GLint}())
        end
        uniforms = _scrape_uniforms(prog,uniform_names)
        return new(prog,uniforms)
    end
end
destroy!(self::ShaderProgram) = (self._id!=0 && glDeleteProgram(self._id))
activate(self::ShaderProgram) = glUseProgram(self._id)

function uniform(self::ShaderProgram,name::String,data)::Nothing
    if self._id == GLuint(0) return nothing end
    if !haskey(self._uniforms,name)
        @log "No Uniform named: $(name)" WARN
        return nothing
    end
    glUniform(self._uniforms[name],data)
end

function _scrape_uniforms(prog::GLuint,names::Vector{String})::Dict{String,GLint}
    namesToLocations = Dict{String,GLint}()
    for name in names
        location = glGetUniformLocation(prog,name)
        if location == -1
            @log "No uniform named: $(name)" WARN
            continue
        end
        namesToLocations[name] = location
    end
    return namesToLocations
end

function _link_shaders(shaders::MVector{5, GLuint})::GLuint
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

        @log "Program linking failed" ERR
        return GLuint(0)
    end
    return prog
end

const _SHADER_EXTENSION_MAP::Dict{String,GLuint} = Dict(
    "comp" => GL_COMPUTE_SHADER,
    "vert" => GL_VERTEX_SHADER,
    "tesc" => GL_TESS_CONTROL_SHADER,
    "tese" => GL_TESS_EVALUATION_SHADER,
    "geom" => GL_GEOMETRY_SHADER,
    "frag" => GL_FRAGMENT_SHADER
)

function _get_shader_stage(shader_path::String)::GLuint
    extension_index = findfirst(==('.'),shader_path)
    if isnothing(extension_index) || extension_index + 1 > length(shader_path)
        @log "Invalid shader path: $(shader_path)" ERR
        return GLuint(0)
    end
    extension::SubString{String} = view(shader_path,extension_index+1:length(shader_path))
    return get(_SHADER_EXTENSION_MAP, extension, GLuint(0))
end

function _create_shader_stage(shader_path::String)::GLuint
    stage::GLuint = _get_shader_stage(shader_path)
    if stage == GLuint(0)
        @log "Failed to create shader stage: $(shader_path)" ERR
        return GLuint(0)
    end

    source::Vector{UInt8} = try
        read(shader_path)
    catch _
        @log "Failed to read file: $(shader_path)" ERR
        return GLuint(0)
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
        
        @log "Failed to compile shader stage: $(shader_path)" ERR
        return GLuint(0)
    end
    return shader
end


