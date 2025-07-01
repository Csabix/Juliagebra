mutable struct ShaderProgram <: OpenGLWrapper
    _id::GLuint
    _uniforms::Dict{String,GLint}

    function ShaderProgram(vertPath::String,fragPath::String,uniformNames::Vector{String}=Vector{String}(undef,0))
        vs = createShaderStage(vertPath,GL_VERTEX_SHADER)
        fs = createShaderStage(fragPath,GL_FRAGMENT_SHADER)
        prog = linkShaders!(vs,fs)
        uniforms = _scrapeUniforms(prog,uniformNames)
        #println(uniforms)
        new(prog,uniforms)
    end
    function ShaderProgram(vertPath::String,geomPath::String,fragPath::String,uniformNames::Vector{String}=Vector{String}(undef,0))
        vs = createShaderStage(vertPath,GL_VERTEX_SHADER)
        gs = createShaderStage(geomPath,GL_GEOMETRY_SHADER)
        fs = createShaderStage(fragPath,GL_FRAGMENT_SHADER)
        prog = linkShaders!(vs,gs,fs)
        uniforms = _scrapeUniforms(prog,uniformNames)
        new(prog,uniforms)
    end
end
destroy!(self::ShaderProgram) = (self._id!=0 && glDeleteProgram(self._id))
activate(self::ShaderProgram) = glUseProgram(self._id)

function setUniform!(self::ShaderProgram,name::String,data::Any)
    if !haskey(self._uniforms,name)
        error("No Uniform named: $(name)!")
    end
    glUniform(self._uniforms[name],data)
end

function _scrapeUniforms(prog::GLuint,names::Vector{String})::Dict{String,GLint}
    namesToLocations = Dict{String,GLint}()
    for name in names
        location = glGetUniformLocation(prog,name)
        if location == -1
            error("Unknown uniform variable: \"$(name)\"!")
        end
        namesToLocations[name] = location
    end
    return namesToLocations
end

function linkShaders!(shaders::GLuint...)::GLuint
    prog = glCreateProgram()
    
    for shader in shaders
        glAttachShader(prog, shader)
    end
    glLinkProgram(prog)
    
    status = Ref{GLint}(0)
    glGetProgramiv(prog, GL_LINK_STATUS, status)
    if status[] == GL_FALSE
        
        infoLogLength = Ref{GLint}(0)
        glGetProgramiv(prog, GL_INFO_LOG_LENGTH, infoLogLength)
        
        infoLog = Vector{UInt8}(undef, infoLogLength[])
        dummyInfoLogLength = Ref{GLint}(0)
        glGetProgramInfoLog(prog, infoLogLength[],dummyInfoLogLength,infoLog)
        
        errorMessage = String(infoLog)
        println(errorMessage)

        glDeleteProgram(prog)
        error("Shader linking failed!")
    end
    return prog
end

function createShaderStage(path::String, stage::GLenum)::GLuint
    source = read(path,String)
    shader = glCreateShader(stage)
    glShaderSource(shader,1,convert(Ptr{UInt8},pointer([convert(Ptr{GLchar},pointer(source))])), C_NULL)
    glCompileShader(shader)
    
    status = Ref{GLint}(0)
    glGetShaderiv(shader, GL_COMPILE_STATUS, status)
    if status[] == GL_FALSE
        
        infoLogLength = Ref{GLint}(0)
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, infoLogLength)
        
        infoLog = Vector{UInt8}(undef, infoLogLength[])
        dummyInfoLogLength = Ref{GLint}(0)
        glGetShaderInfoLog(shader, infoLogLength[],dummyInfoLogLength,infoLog)
        
        errorMessage = String(infoLog)
        println(errorMessage)

        glDeleteShader(shader)
        error("Shader compilation failed in \"$(path)\"!")
    end
    return shader
end


