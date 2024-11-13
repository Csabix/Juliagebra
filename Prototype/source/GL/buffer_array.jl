
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



