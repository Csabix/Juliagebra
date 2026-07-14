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
    _mapped::Vector{T}
    _sync::GLsync

    # these control GL_MAP_WRITE_BIT/GL_MAP_READ_BIT usage in MappedBuffer methods
    _write::Bool
    _read::Bool

    function MappedBuffer{T}(; write::Bool = true, read::Bool = false) where {T}
        @assert isbitstype(T) "OpenGL requires bitstypes."
        @assert write || read "OpenGL requires buffer mappings to be either readable, writeable or both."
        id = Ref{GLuint}()
        glCreateBuffers(1, id)
        new{T}(id[], 0, Vector{T}(), C_NULL, write, read)
    end
end

mutable struct RepeatBufferUBO{T} <: BufferBase{T}
    _id::GLuint
    _size::Int
    _count::Int32
    _min_alignment::GLint
    function RepeatBufferUBO{T}() where {T}
        @assert isbitstype(T) "OpenGL requires bitstypes."
        id = Ref{GLuint}(0)
        glCreateBuffers(1, id)
        min_alignment = Ref{GLint}()
        glGetIntegerv(GL_UNIFORM_BUFFER_OFFSET_ALIGNMENT,min_alignment)
        return new{T}(id[], 0, 0, min_alignment[])
    end
end

# ? ---------------------------------
# ! Methods
# ? ---------------------------------

@inline Base.eltype(::BufferBase{T}) where {T} = T
@inline function Base.length(self::BufferBase{T})::Int where {T}
    return div(self._size, sizeof(T))
end
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
    if length(data) == 0 return false end
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
@inline bind_ubo(self::BufferBase, index) = glBindBufferBase(GL_UNIFORM_BUFFER, index, self._id)
@inline unbind_ssbo(index) = glBindBufferBase(GL_SHADER_STORAGE_BUFFER, index, 0)

# ? ---------------------------------
# ! Methods MappedBuffer
# ? ---------------------------------

@inline function reserve!(self::MappedBuffer{T}, count::Int, flags)::Bool where {T}
    new_storage = _reserve!(self, count, GLbitfield(flags) | _map_flags(self))
    if new_storage
        ptr = glMapNamedBufferRange(self._id, 0, length(self) * sizeof(T), _map_flags(self))
        self._mapped = unsafe_wrap(Array, Ptr{T}(ptr), (length(self),); own = false)
    end
    return new_storage
end

@inline function upload!(self::MappedBuffer{T}, data::AbstractVector{T}, flags)::Bool where {T}
    new_storage = _upload!(self, data, GLbitfield(flags) | _map_flags(self))
    if new_storage
        ptr = glMapNamedBufferRange(self._id, 0, length(self) * sizeof(T), _map_flags(self))
        self._mapped = unsafe_wrap(Array, Ptr{T}(ptr), (length(self),); own = false)
    end
    return new_storage
end

@inline function upload!(self::MappedBuffer{T}, data::AbstractVector{T})::Bool where {T}
    if length(data) == 0 return false end
    glUnmapBuffer(self._id)
    glNamedBufferSubData(self._id, 0, length(data) * sizeof(T), data)
    ptr = glMapNamedBufferRange(self._id, 0, length(self) * sizeof(T), _map_flags(self))
    self._mapped = unsafe_wrap(Array, Ptr{T}(ptr), (length(self),); own = false)
    return false
end

@inline function data(self::MappedBuffer{T}, out_vec=Vector{T}())::Vector{T} where {T}
    N = length(self)
    Base.resize!(out_vec, N)
    if N == 0 return out_vec end

    if !self._read
        glGetNamedBufferSubData(self._id, 0, N * sizeof(T), out_vec)
    else
        copyto!(out_vec, self)
    end

    return out_vec
end

@inline function data(self::MappedBuffer{T}, count::Int, offset::Int, out_vec=Vector{T}())::Vector{T} where {T}
    @assert count <= length(self)
    Base.resize!(out_vec, count)
    if count == 0 return out_vec end

    if !self._read
        glGetNamedBufferSubData(self._id, offset * sizeof(T), count * sizeof(T), out_vec)
    else
        copyto!(out_vec, 1, self._mapped, offset + 1, count)
    end

    return out_vec
end

function Base.setindex!(self::MappedBuffer{T}, value, index::Int) where {T}
    @assert self._write "trying to setindex! into MappedBuffer with non-writeable mapping"
    val_converted = convert(T, value)
    self._mapped[index] = val_converted
    return self
end

function Base.getindex(self::MappedBuffer{T}, index::Int)::T where {T}
    @assert self._read "trying to getindex from MappedBuffer with non-readable mapping"
    return self._mapped[index]
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
    @assert dest._write "trying to copy data to MappedBuffer with non-writeable mapping"
    copyto!(dest._mapped, src)
    return dest
end

function Base.copyto!(dest, src::MappedBuffer)
    @assert src._read "trying to copy data from MappedBuffer with non-readable mapping"
    copyto!(dest, src._mapped)
    return dest
end

# ? ---------------------------------
# ! Methods RepeatBufferUBO
# ? ---------------------------------

@inline function alignment_stride(self::RepeatBufferUBO{T}) where {T}
    return div(sizeof(T) + self._min_alignment - 1, self._min_alignment) * self._min_alignment
end

@inline Base.length(self::RepeatBufferUBO) = Int(self._count)

function reserve!(self::RepeatBufferUBO{T}, count::Int, flags)::Bool where {T}
    if count == 0 return false end
    self._size != 0 && _recreate!(self)
    
    stride = alignment_stride(self)
    bytes = count * stride
    
    glNamedBufferStorage(self._id, bytes, C_NULL, GLbitfield(flags))
    self._size = bytes
    self._count = count
    return true
end

function upload!(self::RepeatBufferUBO{T}, data::AbstractVector{T}, flags)::Bool where {T}
    if length(data) == 0 return false end
    self._size != 0 && _recreate!(self)
    
    stride = alignment_stride(self)
    total_bytes = length(data) * stride
    
    staging = zeros(UInt8, total_bytes)
    for i in 1:length(data)
        offset = (i - 1) * stride
        GC.@preserve staging data begin
            ptr = pointer(staging) + offset
            unsafe_store!(Ptr{T}(ptr), data[i])
        end
    end
    
    glNamedBufferStorage(self._id, total_bytes, staging, GLbitfield(flags))
    self._size = total_bytes
    self._count = length(data)
    return true
end

function upload!(self::RepeatBufferUBO{T}, data::AbstractVector{T})::Bool where {T}
    if length(data) == 0 return false end
    stride = alignment_stride(self)
    @assert length(data) <= self._count "Data length exceeds pre-allocated buffer capacity"

    staging = zeros(UInt8, self._size)
    for i in 1:length(data)
        offset = (i - 1) * stride
        GC.@preserve staging data begin
            ptr = pointer(staging) + offset
            unsafe_store!(Ptr{T}(ptr), data[i])
        end
    end

    glNamedBufferSubData(self._id, 0, self._size, staging)
    return false
end

@inline function bind_ubo(self::RepeatBufferUBO{T}, index::Integer, binding_point::Integer) where {T}
    @assert 1 <= index <= self._count "Index out of range"
    stride = alignment_stride(self)
    offset = (index - 1) * stride
    glBindBufferRange(GL_UNIFORM_BUFFER, binding_point, self._id, offset, sizeof(T))
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

@inline function _map_flags(self::MappedBuffer{T})::GLbitfield where {T}
    bits = GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT
    self._read  && (bits |= GL_MAP_READ_BIT)
    self._write && (bits |= GL_MAP_WRITE_BIT)
    return bits
end
