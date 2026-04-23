# ? ---------------------------------
# ! BufferArray
# ? ---------------------------------

struct BufferArray{T <: Tuple{Vararg{BufferBase}}} <: OpenGLWrapper
    _vbos::T
    _vao::VertexArray

    function BufferArray{T}(attributes::Union{Nothing, AbstractArray} = nothing) where {T <: Tuple{Vararg{BufferBase}}}
        buffers = map(B -> B(), tuple(T.parameters...))
        
        vao = VertexArray()
        
        if isnothing(attributes)
            bind_buffers!(vao, buffers)
        else
            bind_buffers!(vao, buffers, attributes)
        end
        
        return new{T}(buffers, vao)
    end
end

function destroy!(self::BufferArray)
    destroy!(self._vao)
    foreach(destroy!,self._vbos)
end

Base.length(self::BufferArray)::Int = return length(self._vbos[1])
draw(self::BufferArray,mode::GLuint) = (activate(self);glDrawArrays(mode,0,length(self)))
draw(self::BufferArray,mode::GLuint,count::GLsizei) = (activate(self);glDrawArrays(mode,0,count))
activate(self::BufferArray)::Nothing = activate(self._vao)::Nothing

Base.getindex(self::BufferArray, index::Int)::BufferBase = self._vbos[index]
buffer_resized(self::BufferArray, index::Int) = rebind_buffer!(self._vao,index,self._vbos[index])

function reserve!(self::BufferArray, index, count, flags)
    if reserve!(self._vbos[index], count, flags)
        rebind_buffer!(self._vao, index, self._vbos[index])
    end
end
function upload!(self::BufferArray, index, data, flags)
    if upload!(self._vbos[index], data, flags)
        rebind_buffer!(self._vao, index, self._vbos[index])
    end
end
function upload!(self::BufferArray, index, data)
    if upload!(self._vbos[index], data)
        rebind_buffer!(self._vao, index, self._vbos[index])
    end
end

# ? ---------------------------------
# ! IndexedBufferArray
# ? ---------------------------------

struct IndexedBufferArray{T} <: OpenGLWrapper where {T <: Tuple{Vararg{Buffer}}}
    _buffer_array::BufferArray
    _ebo::Buffer

    function IndexedBufferArray{T}() where {T<:Tuple{Vararg{Union{StaticArray,Real}}}}
        buffer_array = BufferArray{T}()
        ebo = Buffer{UInt32}()
        bind_ebo!(buffer_array._vao, ebo)
        new(buffer_array, ebo)
    end
    function IndexedBufferArray{T}(buffer_types...; ebo_type = Buffer) where {T<:Tuple{Vararg{Union{StaticArray,Real}}}}
        buffer_array = BufferArray{T}(buffer_types...)
        ebo = ebo_type{UInt32}()
        bind_ebo!(buffer_array._vao, ebo)
        new(buffer_array, ebo)
    end
end

function destroy!(self::IndexedBufferArray)
    destroy!(self._ebo)
    destroy!(self._buffer_array)
end

Base.length(self::IndexedBufferArray)::Int = return length(self._buffer_array)
draw(self::IndexedBufferArray,mode::GLuint) = (activate(self);glDrawElements(mode,length(self._ebo),GL_UNSIGNED_INT,C_NULL))
draw(self::IndexedBufferArray,mode::GLuint,count::GLsizei) = (activate(self);glDrawElements(mode,count,GL_UNSIGNED_INT,C_NULL))
activate(self::IndexedBufferArray)::Nothing = activate(self._buffer_array)::Nothing

Base.getindex(self::IndexedBufferArray, index::Int)::BufferBase = self._buffer_array[index]
Base.getindex(self::IndexedBufferArray, ::Val{:index})::BufferBase = self._ebo
Base.getindex(self::IndexedBufferArray, s::Symbol)::BufferBase = self[Val(s)]

buffer_resized(self::IndexedBufferArray, index::Int) = buffer_resized(self._buffer_array, index)
buffer_resized(self::IndexedBufferArray, ::Val{:index}) = rebind_ebo!(self._buffer_array._vao, self._ebo)
buffer_resized(self::IndexedBufferArray, s::Symbol) = buffer_resized(self, Val(s))

reserve!(self::IndexedBufferArray, index, count, flags) = reserve!(self._buffer_array, index, count, flags)
upload!(self::IndexedBufferArray, index, data, flags)   = upload!(self._buffer_array, index, data, flags)
upload!(self::IndexedBufferArray, index, data)          = upload!(self._buffer_array, index, data)

function reserve_index!(self::IndexedBufferArray, count, flags)
    if reserve!(self._ebo, count, flags)
        rebind_ebo!(self._buffer_array._vao, self._ebo)
    end
    vao_ebo_method!(self._buffer_array._vao, self._ebo, reserve!, count, flags)
end
function upload_index!(self::IndexedBufferArray, data, flags)
    if upload!(self._ebo, data, flags)
        rebind_ebo!(self._buffer_array._vao, self._ebo)
    end
end
function upload_index!(self::IndexedBufferArray, data)
    if uplodad!(self._ebo, data)
        rebind_ebo!(self._buffer_array._vao, self._ebo)
    end
end
