module GL

using ImGuiOpenGLBackend.ModernGL
using StaticArrays
# include("glutils.jl")
# using .GlUtils

import Base:bind

#exports all enum instances
macro exported_enum(T, B, syms...)
    return esc(quote
        @enum($T::$B, $(syms...))
        export $T
        for inst in Symbol.(instances($T))
            eval($(Expr(:quote, :(export $(Expr(:$, :inst))))))
        end
    end)
end

abstract type AbstractObject end
export bind, delete;

bind(x::AbstractObject) = error("not implemented for $typeof(x)")
delete(x::AbstractObject) = error("not implemented for $typeof(x)")

function glGenOne(glGenF) :: GLuint
    id = GLuint[0]
    glGenF(1,id)
    return id[]
end

#glGet*
export glGetBoolean,glGetDouble,glGetFloat,glGetInteger,glGetInteger64
const IndexType = Union{GLuint,Int};
for (glsuffix,jltype) in ("Boolean"=> Bool,"Double"=>Float64,"Float"=>Float32,"Integer"=>Int32,"Integer64"=>Int64)
    glfunci_v = Symbol("glGet"*glsuffix*"i_v")
    glfuncv = Symbol("glGet"*glsuffix*"v")
    jlfunc = Symbol("glGet"*glsuffix)
    @eval function $jlfunc(target::GLenum)::$jltype
        data = $jltype[0]
        $glfuncv(target,data)
        return data[1]
    end
    @eval function $jlfunc(target::GLenum,index::IndexType)::$jltype
        data = $jltype[0]
        $glfunci_v(target,index,data)
        return data[1]
    end
end

# //////////////////////////////////////////////////////////////////////
# \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\

@exported_enum BufferType GLenum begin
    ARRAY_BUFFER               = GL_ARRAY_BUFFER              # Vertex attributes
    ATOMIC_COUNTER_BUFFER      = GL_ATOMIC_COUNTER_BUFFER     # Atomic counter storage
    COPY_READ_BUFFER           = GL_COPY_READ_BUFFER          # Buffer copy source
    COPY_WRITE_BUFFER          = GL_COPY_WRITE_BUFFER	      # Buffer copy destination
    DISPATCH_INDIRECT_BUFFER   = GL_DISPATCH_INDIRECT_BUFFER  # Indirect compute dispatch commands
    DRAW_INDIRECT_BUFFER	   = GL_DRAW_INDIRECT_BUFFER	  # Indirect command arguments
    ELEMENT_ARRAY_BUFFER	   = GL_ELEMENT_ARRAY_BUFFER	  # Vertex array indices
    PIXEL_PACK_BUFFER	       = GL_PIXEL_PACK_BUFFER	      # Pixel read target
    PIXEL_UNPACK_BUFFER	       = GL_PIXEL_UNPACK_BUFFER	      # Texture data source
    QUERY_BUFFER	           = GL_QUERY_BUFFER	          # Query result buffer
    SHADER_STORAGE_BUFFER	   = GL_SHADER_STORAGE_BUFFER	  # Read-write storage for shaders
    TEXTURE_BUFFER	           = GL_TEXTURE_BUFFER	          # Texture data buffer
    TRANSFORM_FEEDBACK_BUFFER  = GL_TRANSFORM_FEEDBACK_BUFFER # Transform feedback buffer
    UNIFORM_BUFFER	           = GL_UNIFORM_BUFFER	          # Uniform block storage
end

#
export Buffer
# ===================
export bufferData, upload!

mutable struct Buffer <: AbstractObject
    id :: GLuint # opengl object name
    #Buffer() = glObjGenDel!(new(0),glGenBuffers,glDeleteBuffers);
    Buffer() = new(glGenOne(glGenBuffers))
end
delete(x::Buffer) = glDeleteBuffers(1,[x.id])
bind(buffer::Buffer, target::BufferType = ARRAY_BUFFER) = bind(target,buffer)
bind(target::BufferType, buffer::Buffer) = glBindBuffer(GLenum(target),buffer.id)

function bufferData(target::BufferType, data::Vector)
    @assert isbitstype(eltype(data)) "input array is not contiguous in memory"
    glBufferData(GLenum(target), sizeof(data), data, GL_STATIC_DRAW)
end
function bufferData(buffer::Buffer,target::BufferType, data::Vector)
    bind(buffer.id, target)
    bufferData(target, data)
end

function upload!(buffer::Buffer,data::Vector{T} where T)
    glNamedBufferData(buffer.id,sizeof(data),data,GL_STATIC_DRAW)
end

#
export VertexArray
# ===================
export vertexAttribs

mutable struct VertexArray <: AbstractObject
    id::GLuint
    # VertexArray() = glObjGenDel!(new(0),glGenVertexArrays,glDeleteVertexArrays);
    VertexArray() = new(glGenOne(glGenVertexArrays));
end
delete(x::VertexArray) = glDeleteVertexArrays(1,[x.id])
bind(vao::VertexArray) = glBindVertexArray(vao.id)

const JuliaType2OpenGL = Dict([
    Float16 => GL_HALF_FLOAT,
    Float32 => GL_FLOAT,
    Float64 => GL_DOUBLE,
    Int8    => GL_BYTE,
    Int16   => GL_SHORT,
    Int32   => GL_INT,
    UInt8   => GL_UNSIGNED_BYTE,
    UInt16  => GL_UNSIGNED_SHORT,
    UInt32  => GL_UNSIGNED_INT,
])

function vertexAttrib(index::Int, atype::DataType, stride::Int = sizeof(atype), offset::UInt = 0)
    size::GLint = atype <: StaticArray ? length(atype) : 1
    @assert 1<=size<=4 "invalid vertex attrib size"
    elem::DataType = atype <: StaticArray ? eltype(atype) : atype
    @assert 1<=sizeof(elem)<=8 "invalid base type for vertex"
    type::GLenum = JuliaType2OpenGL[elem]                       # dictionary
    normalized::GLenum = elem <: Integer ? GL_TRUE : GL_FALSE   # normalized by default
    glEnableVertexAttribArray(GLuint(index))
    glVertexAttribPointer(GLuint(index),size,type,normalized,GLsizei(stride),Ptr{Nothing}(offset))
    #println("glVertexAttribPointer(GLuint($index),$size,$ype,$normalized,GLsizei($stride),$(Ptr{Nothing}(offset)))");
end

function vertexAttribs(vtype::DataType)
    if vtype <: StaticArray || vtype <: Real
        vertexAttrib(0,vtype)
    else
        stride::Int = sizeof(vtype)
        ltypes = vtype.types
        for i in eachindex(ltypes)
            vertexAttrib(i-1,ltypes[i],stride,fieldoffset(vtype,i))
        end
    end
end

function getInfoLog(obj::GLuint)::String
	isShader = glIsShader(obj)
	getiv = isShader == GL_TRUE ? glGetShaderiv : glGetProgramiv
	getInfo = isShader == GL_TRUE ? glGetShaderInfoLog : glGetProgramInfoLog
	maxlength = GLint[0]; getiv(obj, GL_INFO_LOG_LENGTH, maxlength)
	if maxlength[] > 0
		buffer = zeros(GLchar, maxlength[])
		sizei = GLsizei[0]
		getInfo(obj, maxlength[], sizei, buffer)
		return unsafe_string(pointer(buffer), sizei[])
	else
		return ""
	end
end
function createShader(file::String, typ::GLenum)::GLuint
    source = read(file,String)
    shader = glCreateShader(typ)
    glShaderSource(shader,1,convert(Ptr{UInt8},pointer([convert(Ptr{GLchar},pointer(source))])), C_NULL)
    glCompileShader(shader)
    success = GLint[0];	glGetShaderiv(shader, GL_COMPILE_STATUS, success)
    if success[] != GL_TRUE
        if typ == GL_VERTEX_SHADER
            type, col = "vertex", 2
        elseif typ == GL_FRAGMENT_SHADER
            type, col = "fragment", 6
        else
            type, col = "unknown", 1
        end
		printstyled("ERROR compiling "; color = 1, bold=true)
        printstyled(file,' '; color = col, underline=true, bold=true)
        printstyled(type, " shader:\n\n"; color = 8)
        printstyled(getInfoLog(shader),"\n\n"; color = col, bold=true)
        glDeleteShader(shader);
        return 0
    end
    return shader
end

function createProgram(vertFile::String,fragFile::String)::GLuint
    prog = glCreateProgram()
    vs = createShader(vertFile,GL_VERTEX_SHADER)
    fs = createShader(fragFile,GL_FRAGMENT_SHADER)
    if fs == 0 || vs == 0; return 0; end
	glAttachShader(prog, vs)
	glAttachShader(prog, fs)
	glLinkProgram(prog)
	status = GLint[0];	glGetProgramiv(prog, GL_LINK_STATUS, status)
	if status[] == GL_FALSE
		printstyled("ERROR linking "; color = 1, bold=true)
        printstyled(vertFile; color = 2, underline = true, bold=true)
        printstyled(" vertex and "; color = 8)
        printstyled(fragFile; color = 6, underline = true, bold=true)
        printstyled(" fragment shaders:\n\n"; color = 8)
        printstyled(getInfoLog(prog),"\n\n"; color = 11, bold = true)
	end
    glDeleteShader(vs);
    glDeleteShader(fs);
	return prog
end

#
export Program
# ===================
export use, setUniform, setTexture

mutable struct Program <: AbstractObject
    id::GLuint
    Program() = new(0)
    Program(vertFile::String,fragFile::String)= new(createProgram(vertFile,fragFile))
end
delete(x::Program) = x.id!=0 && glDeleteProgram(x.id)
bind(prog::Program) = glUseProgram(prog.id)
const use = bind;

const LocType = Union{GLint,Int};

# generate automatic glUniform functions
for (jltype,glsuffix) in (Float32=>"f", Float64=>"d", Int32=>"i", UInt32=>"ui")
    glfunc = Symbol("glUniform1"*glsuffix)
    # println(glfunc)
    @eval glUniform(loc::LocType, data::$jltype)::Nothing = $glfunc(loc, data)
    for veclen in 2:4
        gltype = StaticVector{veclen,jltype}
        glfunc = Symbol("glUniform"*string(veclen)*glsuffix)
        # println(glfunc)
        @eval glUniform(loc::LocType, data::$gltype)::Nothing = $glfunc(loc, data...)
        gvtype = Vector{gltype}
        glfunc = Symbol("glUniform"*string(veclen)*glsuffix*"v")
        # println(glfunc)
        @eval glUniform(loc::LocType, data::$gvtype)::Nothing = $glfunc(loc, length(data), data)
    end
    gltype = AbstractVector{jltype}
    @eval function glUniform(loc::LocType, data::$gltype)::Nothing
        N = length(data)
        if 2<=N<=4
            glUniform(loc,SVector{N,$jltype}(data...))
        else
            glfunc = Symbol("glUniform1"*glsuffix*"v")
            @eval glUniform(loc::LocType, data::$jltype)::Nothing = $glfunc(loc, length(data), data)
        end
    end
end
for (jltype,glsuffix) in (Float32=>"fv", Float64=>"dv") #no int support
    for N = 2:4, M = 2:4
        gltype = StaticMatrix{N,M,jltype}
        sizestr= N==M ? string(N) : string(N)*string(M)
        glfunc = Symbol("glUniformMatrix"*sizestr*glsuffix)
        # println(glfunc)
        @eval glUniform(loc::LocType, data::$gltype)::Nothing = $glfunc(loc, 1, GL_FALSE, data)  
        gvtype = Vector{gltype}
        @eval glUniform(loc::LocType, data::$gvtype)::Nothing = $glfunc(loc, length(data), data)
    end
    gltype = AbstractMatrix{jltype}
    @eval function glUniform(loc::LocType, data::$gltype)::Nothing
        (N,M) = size(data)
        if 2<=N<=4 && 2<=M<=4
            glUniform(loc,SMatrix{N,M,$jltype}(data...))
        elseif N==1
            glUniform(loc,SVector{M,$jltype}(data...))  
        elseif M==1
            glUniform(loc,SVector{N,$jltype}(data...))            
        else
            error("Invalid matrix size: $N x $M")
        end
    end
end

const StringOrLoc = Union{String,LocType};

setUniform(id::GLuint, loc::LocType, val::Any)::Nothing = id!=0 ? glUniform(loc,val) : nothing

setUniform(id::GLuint, key::String, val::Any)::Nothing = id!=0 ? glUniform(glGetUniformLocation(id, key),val) : nothing

setUniform(prog::Program, keyloc::StringOrLoc, val::Any)::Nothing = setUniform(prog.id, keyloc, val)

setUniform(key::StringOrLoc, val::Any)::Nothing =  setUniform(GLuint(glGetInteger(GL_CURRENT_PROGRAM)), key, val)

#
export Texture2D
# ===================
export getPixel1i

mutable struct Texture2D <: AbstractObject
    id :: GLuint
    internalFormat ::GLenum
    function Texture2D(internalFormat::GLenum)
        tex = new(glGenOne(glGenTextures),internalFormat)
        bind(tex)
        return tex
    end
end
delete(x::Texture2D) = glDeleteTextures(1,[x.id])
bind(tex::Texture2D) = glBindTexture(GL_TEXTURE_2D,tex.id)

function Texture2D(internalFormat::GLenum, width, height)
    tex = Texture2D(internalFormat)
    glTextureStorage2D(tex.id,1,internalFormat,width,height)
    return tex;
end

function getPixel1i(tex::Texture2D,x::GLint,y::GLint) :: GLint
    @assert tex.internalFormat == GL_R32I "getPixel is only implemented for single channel Int32 ($(tex.internalFormat) != $GL_R32I)"
    parr = GLint[0]
    glGetTextureSubImage(tex.id,0,x,y,0,1,1,1,GL_RED_INTEGER,GL_INT,sizeof(parr),Ptr{Cvoid}(pointer(parr)))
    #println("image($x,$y)=$(parr[])")
    return parr[]
end

function setTexture(prog::Union{GLuint,Program}, keyloc::StringOrLoc, val::Texture2D, index::LocType)::Nothing
    glActiveTexture(GL_TEXTURE0 + index); bind(val)
    setUniform(prog,keyloc,GLint(index))
end
setTexture(keyloc::StringOrLoc, val::Texture2D, index::LocType)::Nothing = setTexture(GLuint(glGetInteger(GL_CURRENT_PROGRAM)),keyloc,val,index)

#
export Framebuffer
# ===================
export attach, complete

mutable struct Framebuffer <: AbstractObject
    id :: GLuint
    attachments :: Set{GLenum}
    function Framebuffer()
        fbo = new(glGenOne(glGenFramebuffers),Set{GLenum}());
        bind(fbo);
        return fbo;
    end
end
delete(x::Framebuffer) = glDeleteFramebuffers(1,[x.id])
bind(fbo::Framebuffer) = glBindFramebuffer(GL_FRAMEBUFFER,fbo.id)

function attach(fbo::Framebuffer, tex::Texture2D, attachment::GLenum, level::GLint=GLint(0))
    glNamedFramebufferTexture(fbo.id,attachment,tex.id,level)
    push!(fbo.attachments,attachment)
end

function complete(fbo::Framebuffer)
    drawAttachments = setdiff(fbo.attachments,GL_DEPTH_ATTACHMENT,GL_STENCIL_ATTACHMENT)
    drawBuffs :: Vector{GLenum} = collect(drawAttachments)
    glNamedFramebufferDrawBuffers(fbo.id,length(drawBuffs),drawBuffs)
    status = glCheckNamedFramebufferStatus(fbo.id,GL_FRAMEBUFFER)
    if status != GL_FRAMEBUFFER_COMPLETE
        error("Framebuffer is incomplete. Status = $status")
    end
end

end # module GL