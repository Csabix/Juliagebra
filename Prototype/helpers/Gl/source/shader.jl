mutable struct ShaderProgram <: OpenGLWrapper
    _id::GLuint

    function ShaderProgram(vertPath::String,fragPath::String)
        vs = createShaderStage(vertPath,GL_VERTEX_SHADER)
        fs = createShaderStage(fragPath,GL_FRAGMENT_SHADER)
        prog = linkShaders!(vs,fs)
        new(prog)
    end
    function ShaderProgram(vertPath::String,geomPath::String,fragPath::String)
        vs = createShaderStage(vertPath,GL_VERTEX_SHADER)
        gs = createShaderStage(geomPath,GL_GEOMETRY_SHADER)
        fs = createShaderStage(fragPath,GL_FRAGMENT_SHADER)
        prog = linkShaders!(vs,gs,fs)
        new(prog)
    end
end
destroy!(self::ShaderProgram) = (self._id!=0 && glDeleteProgram(self._id))
activate(self::ShaderProgram) = (glUseProgram(self._id))

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
        error("Shader compilation failed!")
    end
    return shader
end

export ShaderProgram, activate, destroy!