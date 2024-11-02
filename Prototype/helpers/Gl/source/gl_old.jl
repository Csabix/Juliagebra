module Gl

import Base.length
using StaticArrays, ModernGL

######################
#       Utils        #
######################

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

abstract type OpenGLWrapper end

activate(x::OpenGLWrapper) = error("not implemented for $typeof(x)")
destroy!(x::OpenGLWrapper) = error("not implemented for $typeof(x)")

export destroy!, activate

"""
Generate one id with the specified input glGenFunction.
"""  
function glGenOne(glGenFunction) :: GLuint
  
    # Many openGL genFunctions require pointers as inputs, and a 1 long array should suffice for this
    id = GLuint[0] 
    glGenFunction(1,id)
    return id[]
end

# glGet*
# These commands return values for simple state variables in GL.
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

######################
#       Buffer       #
######################

mutable struct Bufferr <:OpenGLWrapper
    _id::GLuint
    _usage::GLuint
    _numOfItems::Int

    function Bufferr(usage::GLuint)
        id = Ref{GLuint}(0)
        glGenBuffers(1,id)
        id = id[]
        self = new(id,usage,0)
        update!(self,[])

        return self
    end
end

function update!(self::Bufferr,data::Vector)
    self._numOfItems = length(data)
    glBindBuffer(GL_ARRAY_BUFFER,self._id)
    glBufferData(GL_ARRAY_BUFFER,sizeof(data),data,self._usage)
end

update!(self::Bufferr,data::Vector,usage::GLuint) = (self._usage = usage;update!(self,data))
activate(self::Bufferr) = glBindBuffer(GL_ARRAY_BUFFER,self._id)
destroy!(self::Bufferr) = glDeleteBuffers(1,[self._id])
draw(mode::GLuint,length::Int) = glDrawArrays(mode,0,length)
draw(self::Bufferr,mode::GLuint) = draw(mode,self._numOfItems) 

export Bufferr, update!, activate, destroy!, draw

mutable struct Buffer <: OpenGLWrapper
    id :: GLuint # opengl object name
    #Buffer() = glObjGenDel!(new(0),glGenBuffers,glDeleteBuffers);
    Buffer() = new(glGenOne(glGenBuffers))
end
destroy!(x::Buffer) = glDeleteBuffers(1,[x.id])
activate(buffer::Buffer, target::BufferType = ARRAY_BUFFER) = activate(target,buffer)
activate(target::BufferType, buffer::Buffer) = glBindBuffer(GLenum(target),buffer.id)

function bufferData(target::BufferType, data::Vector)
    @assert isbitstype(eltype(data)) "input array is not contiguous in memory"
    glBufferData(GLenum(target), sizeof(data), data, GL_STATIC_DRAW)
end
function bufferData(buffer::Buffer,target::BufferType, data::Vector)
    activate(buffer.id, target)
    bufferData(target, data)
end

function upload!(buffer::Buffer,data::Vector{T} where T)
    glNamedBufferData(buffer.id,sizeof(data),data,GL_STATIC_DRAW)
end

export Buffer, bufferData, upload!, activate, destroy!

######################
#     VertexArray    #
######################

mutable struct VertexArray <: OpenGLWrapper
    _id::GLuint
    _itemType::DataType
    # VertexArray() = glObjGenDel!(new(0),glGenVertexArrays,glDeleteVertexArrays);
    
    function VertexArray(itemType::DataType)
        id = Ref{GLuint}(0)
        glGenVertexArrays(1,id)
        id = id[]
        self = new(id)
        
        activate(self)
        _vertexAttribs(itemType)
        return self
    end
end
destroy!(x::VertexArray) = glDeleteVertexArrays(1,[x._id])
activate(vao::VertexArray) = glBindVertexArray(vao._id)

export VertexArray, activate, destroy!

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
"""
Function to create a vertexAttribPointer.

# Arguments:
- `index`  -> layout(location = index)
- `atype`  -> The type of the attribute data (Float32, Vec3 ...)
- `stride` -> how mutch to jump to find the start of the next element for all this attribute
- `offset` -> offset in bytes inside 1 stride

# For example see:

If data is stored in an array like:

`[vec3,vec2,float,vec3,vec2,float,vec3,vec2,float...]`

If `vec3`, `vec2`, `float` is 1 big element in a buffer, then `layout (location = 0)` is `vec3`, `1` is `vec2`, `2` is `float`.
`index` is for layout, `atype` for `vec3`,`vec2`,`float`. `stride` must be `sizeof(vec3)+sizeof(vec2)+sizeof(float)` and `offset` must be
`0` for `vec3`, `sizeof(vec3)` for `vec2`, `sizeof(vec3) + sizeof(vec2)` for `float`.

"""
function _vertexAttrib(index::Int, atype::DataType, stride::Int = sizeof(atype), offset::UInt = UInt(0))
    #get number of components (3 for vec3)
    size::GLint = atype <: StaticArray ? length(atype) : 1
    @assert 1<=size<=4 "invalid vertex attrib size"
    elem::DataType = atype <: StaticArray ? eltype(atype) : atype
    @assert 1<=sizeof(elem)<=8 "invalid base type for vertex"
    type::GLenum = JuliaType2OpenGL[elem]                       # dictionary
    normalized::GLenum = elem <: Integer ? GL_TRUE : GL_FALSE   # normalized by default
    glEnableVertexAttribArray(GLuint(index))
    #stride needs to be converted into GLsizei type | pointer to offset (where the pointer doesnt know tha data it's reffering to, hence why Nothing is passed)
    glVertexAttribPointer(GLuint(index),size,type,normalized,GLsizei(stride),Ptr{Nothing}(offset))
    #println("\tglVertexAttribPointer(index=$index,size=$size,type=$type,normalized=$normalized,stride=$stride,offset=$offset)");
end
"""
Shorter function to automatically create a vertexAttribPointer from arguments.

# Arguments:
- `vtype` -> could be a single type, like vec3 or it could be a complex struct type.

"""
function _vertexAttribs(vtype::DataType)
    if vtype <: StaticArray || vtype <: Real
        _vertexAttrib(0,vtype)
    else
        stride::Int = sizeof(vtype)
        ltypes = vtype.types
        for i in eachindex(ltypes)
            # fieldoffset tells the byte offset of the i-th type in vtype.
            _vertexAttrib(i-1,ltypes[i],stride,UInt(fieldoffset(vtype,i)))
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

######################
#      Shader        #
######################
mutable struct ShaderProgram <: OpenGLWrapper
    id::GLuint
    #ShaderProgram() = new(0)
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
destroy!(x::ShaderProgram) = (x.id!=0 && glDeleteProgram(x.id))
activate(prog::ShaderProgram) = (glUseProgram(prog.id))

export activate, destroy!

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

######################
#      Uniforms      #
######################

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

setUniform(prog::ShaderProgram, keyloc::StringOrLoc, val::Any)::Nothing = setUniform(prog.id, keyloc, val)

setUniform(key::StringOrLoc, val::Any)::Nothing =  setUniform(GLuint(glGetInteger(GL_CURRENT_PROGRAM)), key, val)

export setUniform, setTexture

# TODO: Clean up unused definitions.
# TODO: Clean up comments.


######################
#      Texture2D     #
######################



#=

mutable struct Texture2D <: OpenGLWrapper
    id :: GLuint
    internalFormat ::GLenum
    function Texture2D(internalFormat::GLenum)
        tex = new(glGenOne(glGenTextures),internalFormat)
        activate(tex)
        return tex
    end
end
destroy!(x::Texture2D) = glDeleteTextures(1,[x.id])
activate(tex::Texture2D) = glBindTexture(GL_TEXTURE_2D,tex.id)

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

function setTexture(prog::Union{GLuint,ShaderProgram}, keyloc::StringOrLoc, val::Texture2D, index::LocType)::Nothing
    glActiveTexture(GL_TEXTURE0 + index); activate(val)
    setUniform(prog,keyloc,GLint(index))
end
setTexture(keyloc::StringOrLoc, val::Texture2D, index::LocType)::Nothing = setTexture(GLuint(glGetInteger(GL_CURRENT_PROGRAM)),keyloc,val,index)

=#



mutable struct Texture22D <: OpenGLWrapper
    _id::GLuint
    #_unit::GLuint #Like GL_TEXTURE0 wich is first input texture
    _width::Int
    _height::Int
    _internalFormat::GLuint
    _uploadFormat::GLuint
    _eachDataType::GLuint

    function Texture22D(width::Int,height::Int,internalFormat::GLuint,uploadFormat::GLuint,eachDataType::GLuint)
        glPixelStorei(GL_UNPACK_ALIGNMENT, 1)
        
        id = Ref{GLuint}(0)
        glGenTextures(1,id)
        id = id[]
        
        self = new(id,width,height,internalFormat,uploadFormat,eachDataType)
        update!(self)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)

        return self
    end
end

function _updateSomeTexture!(id::GLuint,width::Int,height::Int,internalFormat::GLuint,uploadFormat::GLuint,eachDataType::GLuint,data=C_NULL)
    glBindTexture(GL_TEXTURE_2D, id)
    glTexImage2D(GL_TEXTURE_2D,0,internalFormat,width,height,0,uploadFormat,eachDataType,data)
end

activate(self::Texture22D,unit::GLuint) = (glActiveTexture(unit); glBindTexture(GL_TEXTURE_2D, self._id))
update!(self::Texture22D,data) = _updateSomeTexture!(self._id,self._width,self._height,self._internalFormat,self._uploadFormat,self._eachDataType,data)
update!(self::Texture22D) = update!(self,C_NULL)
destroy!(self::Texture22D) = glDeleteTextures(1,[self._id])

createRGBATexture2D(width::Int,height::Int)::Texture22D = Texture22D(width,height,GL_RGBA,GL_RGBA,GL_UNSIGNED_BYTE)
createIDTexture2D(width::Int,height::Int)::Texture22D = Texture22D(width,height,GL_R32I,GL_RED_INTEGER,GL_UNSIGNED_INT)
createDepthTexture2D(width::Int,height::Int)::Texture22D = Texture22D(width,height,GL_DEPTH_COMPONENT,GL_DEPTH_COMPONENT,GL_FLOAT)

export Texture22D, getPixel1i, setTexture, activate, destroy!, update!, createRGBATexture2D, createIDTexture2D, createDepthTexture2D

# RenderBuffer
#=
mutable struct RenderBuffer
    _id::GLuint
    _width::Int
    _height::Int
    _internalFormat::GLuint

    function RenderBuffer(width::Int,height::Int,internalFormat::GLuint,fboAttachmentPoint::GLuint)
        id = Ref{GLuint}(0)
        glGenRenderbuffers(1,id)
        id = id[]
        
        self = new(id,width,height,internalFormat)
        update!(self)
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, fboAttachmentPoint, GL_RENDERBUFFER, self._id)

        return self
    end

end

function _updateSomeRenderBuffer!(id::GLuint,width::Int,height::Int,internalFormat::GLuint)
    glBindRenderbuffer(GL_RENDERBUFFER,id)
    glRenderbufferStorage(GL_RENDERBUFFER, internalFormat, width, height)
end

update!(self::RenderBuffer) = _updateSomeRenderBuffer!(self._id,self._width,self._height,self._internalFormat)
destroy!(self::RenderBuffer) = glDeleteRenderbuffers(1,[self._id])
=#


######################
#     Framebuffer    #
######################

#=
mutable struct Framebuffer <: OpenGLWrapper
    id :: GLuint
    attachments :: Set{GLenum}
    function Framebuffer()
        fbo = new(glGenOne(glGenFramebuffers),Set{GLenum}());
        activate(fbo);
        return fbo;
    end
end
destroy!(x::Framebuffer) = glDeleteFramebuffers(1,[x.id])
activate(fbo::Framebuffer) = glBindFramebuffer(GL_FRAMEBUFFER,fbo.id)

function attach(fbo::Framebuffer, tex::Texture2D, attachment::GLenum, level::GLint=GLint(0))
    glNamedFramebufferTexture(fbo.id,attachment,tex.id,level)
    push!(fbo.attachments,attachment)
    return tex
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
=#

mutable struct FrameBuffer
    _id::GLuint

    function FrameBuffer(attachements::Dict{GLuint,Texture22D})
        id = Ref{GLuint}(0)
        glGenFramebuffers(1,id)
        id = id[]

        self = new(id)
        activate(self)

        attachmentPoints = Vector{GLenum}(undef,0)

        for (attachementPoint,texture) in attachements
            #println("$(attachementPoint) - $(texture._id)")
            
            glFramebufferTexture(GL_FRAMEBUFFER, attachementPoint, texture._id, 0)
            if attachementPoint != GL_DEPTH_ATTACHMENT
                push!(attachmentPoints,attachementPoint)
            end
        end

        glDrawBuffers(length(attachmentPoints), attachmentPoints)
        if(glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
            error("FrameBuffer creation failed!")
        end
        
        disable(self)

        return self
    end
end

activate(self::FrameBuffer) = glBindFramebuffer(GL_FRAMEBUFFER, self._id)
disable(self::FrameBuffer) = glBindFramebuffer(GL_FRAMEBUFFER, 0)
destroy!(self::FrameBuffer) =  glDeleteRenderbuffers(1,[self._id])

export FrameBuffer, attach, complete, activate, destroy!, disable




######################
#    SyncedBuffer    #
######################

mutable struct SyncedBuffer{T}
    val :: Vector{T}
    vbo :: Buffer
    vao :: VertexArray
    function SyncedBuffer{T}() where T
        sa = new{T}(Vector{T}(),Buffer(),VertexArray())
        activate(sa.vao); activate(sa.vbo) # TODO why need GL. ?
        _vertexAttribs(T)
        return sa
    end
end
upload!(sa::SyncedBuffer) = upload!(sa.vbo,sa.val)
upload!(sa::SyncedBuffer{T},v::Vector{T}) where T = begin sa.val=v; upload!(sa) end
length(sa::SyncedBuffer) = Base.length(sa.val)
activate(sa::SyncedBuffer) = activate(sa.vao)
destroy!(sa::SyncedBuffer{T}) where T = begin destroy!(sa.vao); destroy!(sa.vbo); sa.val=Vector{T}[] end

export SyncedBuffer, upload!, upload!, length, activate, destroy!

end # module OGL