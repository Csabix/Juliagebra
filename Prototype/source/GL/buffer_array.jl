# ? ---------------------------------
# ! BufferArray
# ? ---------------------------------

draw(mode::GLuint,length::Real) = glDrawArrays(mode,0,length)

mutable struct BufferArray <: OpenGLWrapper
    _numOfItems::GLuint
    _usage::GLuint
    _buffer::Buffer
    _vertexArray::VertexArray
    
    function BufferArray(itemType::DataType,usage::GLuint=GL_STATIC_DRAW,data::Vector=[])
        buffer = Buffer()
        activate(buffer)
        vertexArray = VertexArray(itemType)
        self = new(length(data),usage,buffer,vertexArray)
        
        upload!(self,data)
        return self
    end
end


upload!(self::BufferArray,data::Vector) = (self._numOfItems=length(data);upload!(self._buffer,data,self._usage);deactivate(self._buffer))

draw(self::BufferArray,mode::GLuint) = (activate(self._vertexArray);draw(mode,self._numOfItems))
destroy!(self::BufferArray) = (destroy!(self._vertexArray);destroy!(self._buffer))

# ? ---------------------------------
# ! TypedBufferArray
# ? ---------------------------------

mutable struct TypedBufferArray{T} <: OpenGLWrapper where {T <: Tuple{Vararg{TypedBuffer}}}
    
    _typedBuffers::T
    _vertexArray::VertexArray

    function TypedBufferArray{T}() where {T<:Tuple{Vararg{Union{StaticArray,Real}}}}
        
        buffers = Vector{TypedBuffer}()
        for type in T.parameters
            push!(buffers,TypedBuffer{type}())
        end
        buffers = Tuple(buffers)

        vertexArray = VertexArray(buffers)

        new{typeof(buffers)}(buffers,vertexArray)
    end
end

function destroy!(self::TypedBufferArray)
    destroy!(self._vertexArray)
    for buffer in self._typedBuffers
        destroy!(buffer)
    end
end

Base.length(self::TypedBufferArray)::Int = return length(self._typedBuffers[1])
draw(self::TypedBufferArray,mode::GLuint) = (activate(self._vertexArray);draw(mode,length(self)))
upload!(self::TypedBufferArray,index::Int,data::Vector,usage::GLuint) = upload!(self._typedBuffers[index],data,usage)

# ? ---------------------------------
# ! IndexedTypedBufferArray
# ? ---------------------------------

mutable struct IndexedTypedBufferArray{T} <: OpenGLWrapper
    _typedBuffer::TypedBufferArray{T}
    _indexBuffer::TypedBuffer

    function IndexedTypedBufferArray{T}() where T
        typedBuffer = TypedBufferArray{T}()
        activate(typedBuffer._vertexArray)
        
        indexBuffer = IndexBuffer()
        activate(indexBuffer)
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer._id);
        deactivate(indexBuffer)

        # TODO: move binding to buffer's function.

        new(typedBuffer,indexBuffer)
    end
end

function destroy!(self::IndexedTypedBufferArray)
    destroy!(self._typedBuffer)
    destroy!(self._indexBuffer)
end

upload!(self::IndexedTypedBufferArray,index::Int,data::Vector,usage::GLuint) = upload!(self._typedBuffer,index,data,usage)
uploadIndexes!(self::IndexedTypedBufferArray,data::Vector,usage::GLuint) = upload!(self._indexBuffer,data,usage)

function draw(self::IndexedTypedBufferArray,mode::GLuint)
    activate(self._typedBuffer._vertexArray)
    glDrawElements(mode, length(self._indexBuffer), GL_UNSIGNED_INT, 0);
end
