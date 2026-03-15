# ? ---------------------------------
# ! Buffer
# ? ---------------------------------

abstract type BufferBase{T} <: OpenGLWrapper where {T} end

mutable struct Buffer{T} <: BufferBase{T}
    _id::GLuint
    _size::Int

    function Buffer{T}() where {T}
        @assert isbitstype(T) "OpenGL requires bitstypes."
        id = Ref{GLuint}(0)
        glCreateBuffers(1, id)
        return new{T}(id[], 0)
    end
end

mutable struct MappedBuffer{T} <: BufferBase{T}
    _id::GLuint
    _size::Int
    _mapped::AbstractVector{T}
    _sync::GLsync

    function MappedBuffer{T}() where {T}
        @assert isbitstype(T) "OpenGL requires bitstypes."
        id = Ref{GLuint}()
        glCreateBuffers(1, id)
        new{T}(id[], 0, Vector{T}(), C_NULL)
    end
end

# ? ---------------------------------
# ! Methods
# ? ---------------------------------

@inline Base.eltype(::BufferBase{T}) where {T} = T
@inline Base.length(self::BufferBase{T}) where {T} = div(self._size, sizeof(T))
@inline id(self::BufferBase)::GLuint = self._id
@inline size(self::BufferBase)::Int = self._size

@inline destroy!(self::BufferBase) = glDeleteBuffers(1, [self._id])

@inline function reserve!(self::Buffer{T}, count::Int, flags)::Bool where {T}
    return _reserve!(self, count, GLbitfield(flags))
end

@inline function upload!(self::Buffer{T}, data::AbstractVector{T}, flags)::Bool where {T}
   return _upload!(self, data, GLbitfield(flags))
end

@inline function upload!(self::BufferBase{T}, data::AbstractVector{T})::Bool where {T}
    if length(data) == 0 return end
    glNamedBufferSubData(self._id, 0, length(data) * sizeof(T), data)
    return false
end

@inline function data(self::BufferBase{T}, out_vec=Vector{T}())::Vector{T} where {T}
    N = length(self)
    Base.resize!(out_vec, N)
    if N == 0 return out_vec end
    glGetNamedBufferSubData(self._id, 0, N * sizeof(T), out_vec)
    return out_vec
end
@inline function data(self::BufferBase{T}, count::Int, offset::Int, out_vec=Vector{T}())::Vector{T} where {T}
    @assert count <= length(self)
    Base.resize!(out_vec, count)
    if count == 0 return out_vec end
    glGetNamedBufferSubData(self._id, offset * sizeof(T), count * sizeof(T), out_vec)
    return out_vec
end

@inline bind_ssbo(self::BufferBase, index) = glBindBufferBase(GL_SHADER_STORAGE_BUFFER, index, self._id)

# ? ---------------------------------
# ! Methods MappedBuffer
# ? ---------------------------------

@inline function reserve!(self::MappedBuffer{T}, count::Int, flags)::Bool where {T}
    new_storage = _reserve!(self, count, GLbitfield(flags) | GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT)
    if new_storage
        ptr = glMapNamedBufferRange(self._id, 0, length(self) * sizeof(T), GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT)
        self._mapped = unsafe_wrap(Array, Ptr{T}(ptr), (length(self),); own = false)
    end
    return new_storage
end

@inline function upload!(self::MappedBuffer{T}, data::AbstractVector{T}, flags)::Bool where {T}
    new_storage = _upload!(self, data, GLbitfield(flags) | GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT)
    if new_storage
        ptr = glMapNamedBufferRange(self._id, 0, length(self) * sizeof(T), GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT)
        self._mapped = unsafe_wrap(Array, Ptr{T}(ptr), (length(self),); own = false)
    end
    return new_storage
end

@inline function upload!(self::MappedBuffer{T}, data::AbstractVector{T})::Bool where {T}
    if length(data) == 0 return false end
    glUnmapBuffer(self._id)
    glNamedBufferSubData(self._id, 0, length(data) * sizeof(T), data)
    ptr = glMapNamedBufferRange(self._id, 0, length(self) * sizeof(T), GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT)
    self._mapped = unsafe_wrap(Array, Ptr{T}(ptr), (length(self),); own = false)
    return false
end

function Base.setindex!(self::MappedBuffer{T}, value, index::Int) where {T}
    val_converted = convert(T, value)
    self._mapped[index] = val_converted
    return self
end

function Base.lock(self::MappedBuffer)
    if self._sync != C_NULL
        glDeleteSync(self._sync)
    end
    self._sync = glFenceSync(GL_SYNC_GPU_COMMANDS_COMPLETE, 0)
end

function Base.wait(self::MappedBuffer)
    if self._sync != C_NULL
        while true
            waitReturn = glClientWaitSync(self._sync, GL_SYNC_FLUSH_COMMANDS_BIT, 1000000);
            if waitReturn == GL_ALREADY_SIGNALED || waitReturn == GL_CONDITION_SATISFIED
                return
            end
        end
    end
end

function Base.copyto!(dest::MappedBuffer, src)
    copyto!(dest._mapped, src)
    return dest
end

# ? ---------------------------------
# ! Private Methods
# ? ---------------------------------

@inline function _recreate!(self::BufferBase)
    @assert self._size != 0
    glDeleteBuffers(1, [self._id])
    id = Ref{GLuint}()
    glCreateBuffers(1, id)
    self._id = id[]
    self._size = 0
end

@inline function _reserve!(self::BufferBase{T}, count::Int, flags::GLbitfield)::Bool where {T}
    if count == 0 return false end
    self._size != 0 && _recreate!(self)
    bytes = count * sizeof(T)
    glNamedBufferStorage(self._id, bytes, C_NULL, flags)
    self._size = bytes
    return true
end

@inline function _upload!(self::BufferBase{T}, data::AbstractVector{T}, flags::GLbitfield)::Bool where {T}
    if length(data) == 0 return false end
    self._size != 0 && _recreate!(self)
    bytes = length(data) * sizeof(T)
    glNamedBufferStorage(self._id, bytes, data, flags)
    self._size = bytes
    return true
end