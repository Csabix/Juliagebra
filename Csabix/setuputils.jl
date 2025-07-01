
function rbg2xterm(r::Int, g::Int, b::Int)::Int
    function absdiff(c::Int, x::Int, i::Int)::Int
        return abs(c - (i > 215 ? 8 + (i - 216) * 10 : x * 40 + (x != 0) * 55))
    end
    l = 240
    m = 0
    for i = 240:-1:0
        t = absdiff(r, div(i, 36), i) + absdiff(g, div(i, 6) % 6,i) + absdiff(b, i % 6, i)
        if t < l
            l = t
            m = i
        end
    end
    return m + 16
end

function print_source(source::GLenum)
    _source = ("UNKNOWN",128,128,128)
    if source == GL_DEBUG_SOURCE_API
        _source = ("API",0,128,128)
    elseif source == GL_DEBUG_SOURCE_WINDOW_SYSTEM
        _source = ("WINDOW SYSTEM",200,200,0)
    elseif source == GL_DEBUG_SOURCE_SHADER_COMPILER
        _source = ("SHADER COMPILER",255,128,0)
    elseif source == GL_DEBUG_SOURCE_THIRD_PARTY
        _source = ("THIRD PARTY",128,128,128)
    elseif source == GL_DEBUG_SOURCE_APPLICATION
        _source = ("APPLICATION",128,128,128)
    elseif source == GL_DEBUG_SOURCE_OTHER
        _source = ("UNKNOWN",128,128,128)
    end
    printstyled(_source[1];color=rbg2xterm(_source[2:4]...))
end

function print_type(type::GLenum)
    _type = ("UNKNOWN",128,128,128)
    if type == GL_DEBUG_TYPE_ERROR
        _type = ("ERROR",255,0,0)
    elseif type == GL_DEBUG_TYPE_DEPRECATED_BEHAVIOR
        _type = ("DEPRECATED BEHAVIOR",128,0,0)
    elseif type == GL_DEBUG_TYPE_UNDEFINED_BEHAVIOR
        _type = ("UDEFINED BEHAVIOR",128,50,0)
    elseif type == GL_DEBUG_TYPE_PORTABILITY
        _type = ("PORTABILITY",135, 12, 212)
    elseif type == GL_DEBUG_TYPE_PERFORMANCE
        _type = ("PERFORMANCE",0,0,255)
    elseif type == GL_DEBUG_TYPE_OTHER
        _type = ("OTHER",136, 215, 35)
    elseif type == GL_DEBUG_TYPE_MARKER
        _type = ("MARKER",128,128,128)
    end
    printstyled(_type[1];color=rbg2xterm(_type[2:4]...),bold=true)
end

function print_severity(severity::GLenum)
    _severity = ("UNKNOWN",128,128,128)
    if severity == GL_DEBUG_SEVERITY_HIGH
        _severity = ("HIGH",255,0,0)
    elseif severity == GL_DEBUG_SEVERITY_MEDIUM
        _severity = ("MEDIUM",255,95,0)
    elseif severity == GL_DEBUG_SEVERITY_LOW
        _severity = ("LOW",255,175,0)
    elseif severity == GL_DEBUG_SEVERITY_NOTIFICATION
        _severity = ("NOTIFICATION",255,255,255)
    end
    printstyled(_severity[1];color=rbg2xterm(_severity[2:4]...),bold=true)
end

function OpenGlDebugCallback(source::GLenum, type::GLenum, id::GLuint, severity::GLenum, ::GLsizei, message::Cstring, ::Ptr{Cvoid})::Cvoid
    printstyled("OpenGL debug message [$id]: ";color=rbg2xterm(128,128,128))
    print_type(type)
    printstyled(" of ";color=rbg2xterm(128,128,128))
    print_severity(severity)
    printstyled(" severity, raised from ";color=rbg2xterm(128,128,128))
    print_source(source)
    print(":\n\t")
    printstyled(unsafe_string(message);color=rbg2xterm(255,255,128),bold=true)
    print("\n")
    # str = "OpenGL debug message [$id]: $_type of $_severity severity, raised from $_source: $(unsafe_string(message))"
    if id != GLuint(131218)
        error("OpenGL error")
    end
end

function setGlDebugCallback(window, gl_ctx)
    glfwMakeContextCurrent(window)
    glfwWindowHint(GLFW_OPENGL_DEBUG_CONTEXT, GLFW_TRUE)
    glEnable(GL_DEBUG_OUTPUT)
    glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS)
    glDebugMessageControl(GL_DONT_CARE, GL_DONT_CARE, GL_DEBUG_SEVERITY_NOTIFICATION, 0, C_NULL, GL_FALSE)
    glDebugMessageCallback(@cfunction(OpenGlDebugCallback,Cvoid,(GLenum,GLenum,GLuint,GLenum,GLsizei,Cstring,Ptr{Cvoid})), C_NULL)    
end