# ? ---------------------------------
# ! BufferArray
# ? ---------------------------------

struct BufferArray{T} <: OpenGLWrapper where {T <: Tuple{Vararg{Buffer}}}
    _vbos::T
    _vao::VertexArray

    function _create(T_params, constructors, attributes)
        buffers = Tuple(C{Type}() for (C, Type) in zip(constructors, T_params))
        
        vao = VertexArray()
        
        if isnothing(attributes)
            bind_buffers!(vao, collect(buffers))
        else
            bind_buffers!(vao, collect(buffers), attributes)
        end
        
        return new{typeof(buffers)}(buffers, vao)
    end

    function BufferArray{T}(attributes::Union{Nothing, AbstractArray} = nothing) where {T<:Tuple{Vararg{Union{StaticArray,Real}}}}
        constructors = ntuple(_ -> Buffer, length(T.parameters))
        return _create(T.parameters, constructors, attributes)
    end

    function BufferArray{T}(buffer_types::Type...) where {T<:Tuple{Vararg{Union{StaticArray,Real}}}}
        return _create(T.parameters, buffer_types, nothing)
    end

    function BufferArray{T}(attributes::AbstractArray, buffer_types::Type...) where {T<:Tuple{Vararg{Union{StaticArray,Real}}}}
        return _create(T.parameters, buffer_types, attributes)
    end
end

function destroy!(self::BufferArray)
    destroy!(self._vao)
    destroy!.(self._vbos)
end

Base.length(self::BufferArray)::Int = return length(self._vbos[1])
draw(self::BufferArray,mode::GLuint) = (activate(self);glDrawArrays(mode,0,length(self)))
draw(self::BufferArray,mode::GLuint,count::GLsizei) = (activate(self);glDrawArrays(mode,0,count))
activate(self::BufferArray) = activate(self._vao)

Base.getindex(self::BufferArray, index::Int)::BufferBase = self._vbos[index]
buffer_resized(self::BufferArray, index::Int) = rebind_buffer!(self._vao,index,self._vbos[index])

reserve!(self::BufferArray, index, count, flags) = vao_buffer_method!(self._vao, self._vbos[index], index, reserve!, count, flags)
upload!(self::BufferArray, index, data, flags)   = vao_buffer_method!(self._vao, self._vbos[index], index, upload!, data, flags)
upload!(self::BufferArray, index, data)          = vao_buffer_method!(self._vao, self._vbos[index], index, upload!, data)

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
activate(self::IndexedBufferArray) = activate(self._buffer_array)

Base.getindex(self::IndexedBufferArray, index::Int)::BufferBase = self._buffer_array[index]
Base.getindex(self::IndexedBufferArray, ::Val{:index})::BufferBase = self._ebo
Base.getindex(self::IndexedBufferArray, s::Symbol)::BufferBase = self[Val(s)]

buffer_resized(self::IndexedBufferArray, index::Int) = buffer_resized(self._buffer_array, index)
buffer_resized(self::IndexedBufferArray, ::Val{:index}) = rebind_ebo!(self._buffer_array._vao, self._ebo)
buffer_resized(self::IndexedBufferArray, s::Symbol) = buffer_resized(self, Val(s))

reserve!(self::IndexedBufferArray, index, count, flags) = reserve!(self._buffer_array, index, count, flags)
upload!(self::IndexedBufferArray, index, data, flags)   = upload!(self._buffer_array, index, data, flags)
upload!(self::IndexedBufferArray, index, data)          = upload!(self._buffer_array, index, data)

reserve_index!(self::IndexedBufferArray, count, flags) = vao_ebo_method!(self._buffer_array._vao, self._ebo, reserve!, count, flags)
upload_index!(self::IndexedBufferArray, data, flags)   = vao_ebo_method!(self._buffer_array._vao, self._ebo, upload!, data, flags)
upload_index!(self::IndexedBufferArray, data)          = vao_ebo_method!(self._buffer_array._vao, self._ebo, uplodad!, data)