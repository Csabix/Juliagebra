# ? ---------------------------------
# ! BufferArray
# ? ---------------------------------

struct BufferArray{T} <: OpenGLWrapper where {T <: Tuple{Vararg{Buffer}}}
    _vbos::T
    _vao::VertexArray

    function BufferArray{T}() where {T<:Tuple{Vararg{Union{StaticArray,Real}}}}
        buffers = Buffer[]
        sizehint!(buffers, length(T.parameters))
        for Type in T.parameters
            push!(buffers, Buffer{:Mutable, Type}())
        end

        vao = VertexArray()
        bind_buffers!(vao, buffers)

        buffer_tuple = Tuple(buffers)
        return new{typeof(buffer_tuple)}(buffer_tuple, vao)
    end
end

function destroy!(self::BufferArray)
    destroy!(self._vao)
    destroy!.(self._vbos)
end

Base.length(self::BufferArray)::Int = return length(self._vbos[1])
draw(self::BufferArray,mode::GLuint) = (activate(self);glDrawArrays(mode,0,length(self)))
activate(self::BufferArray) = activate(self._vao)

reserve!(self::BufferArray,index::Int,count::Int,usage::GLenum) = reserve(self._vbos[index],count,usage)
upload!(self::BufferArray,index::Int,data::AbstractVector{T},usage::GLenum) where T = upload!(self._vbos[index],data,usage)
upload!(self::BufferArray,index::Int,data::AbstractVector{T}) where T = upload!(self._vbos[index],data)

# ? ---------------------------------
# ! IndexedBufferArray
# ? ---------------------------------

mutable struct IndexedBufferArray{T} <: OpenGLWrapper where {T <: Tuple{Vararg{Buffer}}}
    _buffer_array::BufferArray
    _ebo::Buffer{:Mutable, UInt32}

    function IndexedBufferArray{T}() where {T<:Tuple{Vararg{Union{StaticArray,Real}}}}
        buffer_array = BufferArray{T}()
        ebo = IndexBufferM()

        bind_ebo!(buffer_array._vao,ebo)

        new(buffer_array,ebo)
    end
end

function destroy!(self::IndexedBufferArray)
    destroy!(self._ebo)
    destroy!(self._buffer_array)
end

Base.length(self::IndexedBufferArray)::Int = return length(self.vbos[1])
draw(self::IndexedBufferArray,mode::GLuint) = (activate(self);glDrawElements(mode,length(self._ebo),GL_UNSIGNED_INT,C_NULL))
activate(self::IndexedBufferArray) = activate(self._buffer_array)

reserve!(self::IndexedBufferArray,index::Int,count::Int,usage::GLenum) = reserve(self._buffer_array,index,count,usage)
upload!(self::IndexedBufferArray,index::Int,data::AbstractVector{T},usage::GLenum) where T = upload!(self._buffer_array,index,data,usage)
upload!(self::IndexedBufferArray,index::Int,data::AbstractVector{T}) where T = upload!(self._buffer_array,index,data)

reserve_indices!(self::IndexedBufferArray,count::Int,usage::GLenum) = reserve(self._ebo,count,usage)
upload_indices!(self::IndexedBufferArray,data::AbstractVector{UInt32},usage::GLenum) = upload!(self._ebo,data,usage)
data_indices!(self::IndexedBufferArray,data::AbstractVector{UInt32}) = upload!(self._ebo,data)