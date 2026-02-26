# ? ---------------------------------
# ! Buffer
# ? ---------------------------------

#@inline copy(read::Buffer, write::_BufferBase, read_offset::GLintptr, write_offset::GLintptr, size::GLsizeiptr)

# TODO @clear(self::Buffer,value)
# TODO @clear(self::_BufferBase,value,offset,count)
# TODO memory map

mutable struct Buffer{Mutable,T} <: OpenGLWrapper where{Mutable,T}
    _id::GLuint
    _size::Int

    function Buffer{M,T}() where {M, T}
        @assert isbitstype(T) "OpenGL requires bitstypes."
        id = Ref{GLuint}()
        glCreateBuffers(1,id)
        new{M,T}(id[],0)
    end

    function Buffer{M,Any}() where M
        id = Ref{GLuint}()
        glCreateBuffers(1,id)
        new{M,Any}(id[],0)
    end
end

# ? ---------------------------------
# ! Helpers
# ? ---------------------------------

const BufferM = Buffer{:Mutable, Any}
const BufferMT{T} = Buffer{:Mutable, T}

const BufferI = Buffer{:Immutable, Any}
const BufferIT{T} = Buffer{:Immutable, T}

const IndexBufferI = Buffer{:Immutable, UInt32}
const IndexBufferM = Buffer{:Mutable, UInt32}

# ? ---------------------------------
# ! Methods
# ? ---------------------------------

@inline Base.eltype(::Buffer{M, T}) where {M, T} = T
@inline Base.eltype(::Buffer{M,Any}) where {M} = error("Can't querry type of an untyped buffer")
@inline Base.length(self::Buffer{M,T}) where {M,T} = count(self)
@inline Base.length(::Buffer{M,Any}) where {M} = error("Can't querry length of an untyped buffer")
@inline size(self::Buffer)::GLuint = self._size
@inline id(self::Buffer)::GLuint = self._id

@inline destroy!(self::Buffer) = glDeleteBuffers(1,[self._id])

@inline function count(self::Buffer{M,Any}, ::Type{T})::Int where {M,T}
    div(self._size,sizeof(T))
end
@inline function count(self::Buffer{M,T})::Int where {M,T}
    div(self._size,sizeof(T))
end

@inline function reserve!(self::Buffer{:Mutable,Any}, size::GLsizeiptr, usage::GLenum)
    glNamedBufferData(self._id,size,C_NULL,usage)
    self._size = size
end
@inline function reserve!(self::Buffer{:Mutable,T}, count::Int, usage::GLenum) where T
    glNamedBufferData(self._id,count*sizeof(T),C_NULL,usage)
    self._size = count*sizeof(T)
end
@inline function reserve!(self::Buffer{:Immutable,Any}, size::GLsizeiptr, flags::GLbitfield)
    @assert size != 0
    self._size != 0 && _recreate!(self)
    glNamedBufferStorage(self._id,size,C_NULL,flags)
    self._size = size
end
@inline function reserve!(self::Buffer{:Immutable,T}, count::Int, flags::GLbitfield) where T
    @assert count != 0
    self._size != 0 && _recreate!(self)
    glNamedBufferStorage(self._id,count*sizeof(T),C_NULL,flags)
    self._size = count*sizeof(T)
end

@inline function upload!(self::Buffer{:Mutable,Any}, data::AbstractVector{T}, usage::GLenum) where T
    @assert isbitstype(T) "OpenGL requires bitstypes."
    glNamedBufferData(self._id,length(data)*sizeof(T),data,usage)
    self._size = length(data)*sizeof(T)
end
@inline function upload!(self::Buffer{:Mutable,T}, data::AbstractVector{T}, usage::GLenum) where T
    glNamedBufferData(self._id,length(data)*sizeof(T),data,usage)
    self._size = length(data)*sizeof(T)
end
@inline function upload!(self::Buffer{:Immutable,Any}, data::AbstractVector{T}, flags::GLbitfield) where T
    @assert isbitstype(T) "OpenGL requires bitstypes."
    @assert length(data) > 0
    self._size != 0 && _recreate!(self)
    glNamedBufferStorage(self._id,length(data)*sizeof(T),data,flags)
    self._size = length(data)*sizeof(T)
end
@inline function upload!(self::Buffer{:Immutable,T}, data::AbstractVector{T}, flags::GLbitfield) where T
    @assert length(data) > 0
    self._size != 0 && _recreate!(self)
    glNamedBufferStorage(self._id,length(data)*sizeof(T),data,flags)
    self._size = length(data)*sizeof(T)
end

@inline function upload!(self::Buffer{M,Any}, data::AbstractVector{T}) where {M,T}
    @assert isbitstype(T) "OpenGL requires bitstypes."
    if length(data) == 0 return end
    invalidate!(self)
    glNamedBufferSubData(self._id,0,length(data)*sizeof(T),data)
end
@inline function upload!(self::Buffer{M,T}, data::AbstractVector{T}) where {M,T}
    if length(data) == 0 return end
    invalidate!(self)
    glNamedBufferSubData(self._id,0,length(data)*sizeof(T),data)
end
@inline function upload!(self::Buffer{M,Any}, data::AbstractVector{T}, offset::Int) where {M,T}
    @assert isbitstype(T) "OpenGL requires bitstypes."
    if length(data) == 0 return end
    glNamedBufferSubData(self._id,offset*sizeof(T),length(data)*sizeof(T),data)
end
@inline function upload!(self::Buffer{M,T}, data::AbstractVector{T}, offset::Int) where {M,T}
    if length(data) == 0 return end
    glNamedBufferSubData(self._id,offset*sizeof(T),length(data)*sizeof(T),data)
end

@inline function data(self::Buffer{M,Any}, ::Type{T}, out_vec=Vector{T}())::Vector{T}() where {M, T}
    @assert isbitstype(T) "OpenGL requires bitstypes."
    n = count(self,T)
    Base.resize!(out_vec,n)
    if n == 0 return out_vec end
    glGetNamedBufferSubData(self._id,0,n*sizeof(T),out_vec)
    return out_vec
end
@inline function data(self::Buffer{M,T}, out_vec=Vector{T}())::Vector{T}() where {M, T}
    n = count(self)
    Base.resize!(out_vec,n)
    if n == 0 return out_vec end
    glGetNamedBufferSubData(self._id,0,n*sizeof(T),out_vec)
    return out_vec
end
@inline function data(self::Buffer{M,Any}, ::Type{T}, offset::Int, count::Int, out_vec=Vector{T}())::Vector{T}() where {M, T}
    @assert isbitstype(T) "OpenGL requires bitstypes."
    Base.resize!(out_vec,count)
    if n == 0 return out_vec end
    glGetNamedBufferSubData(self._id,offset*sizeof(T),count*sizeof(T),out_vec)
    return out_vec
end
@inline function data(self::Buffer{M,T}, offset::Int, count::Int, out_vec=Vector{T}())::Vector{T}() where {M, T}
    Base.resize!(out_vec,count)
    if n == 0 return out_vec end
    glGetNamedBufferSubData(self._id,offset*sizeof(T),count*sizeof(T),out_vec)
    return out_vec
end

@inline invalidate!(self::Buffer) = glInvalidateBufferData(self._id)

@inline bind_ssbo(self::Buffer, index) = glBindBufferBase(GL_SHADER_STORAGE_BUFFER,index,self._id)

@inline function _recreate!(self::Buffer)
    @assert self._size != 0
    glDeleteBuffers(1,[self._id])
    id = Ref{GLuint}()
    glCreateBuffers(1,id)
    self._id = id[]
    self._size = 0
end