# ? ---------------------------------
# ! Buffer
# ? ---------------------------------


mutable struct Buffer <:OpenGLWrapper
    _id::GLuint
    _numOfItems::Int

    function Buffer()
        id = Ref{GLuint}(0)
        glGenBuffers(1,id)
        id = id[]
        self = new(id,0)
        return self
    end
end

function upload!(self::Buffer,data::Vector,usage::GLuint)
    glBindBuffer(GL_ARRAY_BUFFER,self._id)
    self._numOfItems = length(data)

    if self._numOfItems > 0
        @assert isbitstype(eltype(data)) "Input array for Buffer upload is not contiguous in memory"
        #println(reinterpret(Float32, data))
        #println(self._id)
    end
    glBufferData(GL_ARRAY_BUFFER,sizeof(data),data,usage)
    #println("$(sizeof(data)) - $(length(data))")
end

Base.length(self::Buffer)::Int = self._numOfItems
activate(self::Buffer) = glBindBuffer(GL_ARRAY_BUFFER,self._id)
deactivate(self::Buffer) = glBindBuffer(GL_ARRAY_BUFFER,0)
destroy!(self::Buffer) = glDeleteBuffers(1,[self._id])


# ? ---------------------------------
# ! TypedBuffer
# ? ---------------------------------

mutable struct TypedBuffer{T}<:OpenGLWrapper where {T<:Union{StaticArray,Real}} 
    _buffer::Buffer

    function TypedBuffer{T}() where {T<:Union{StaticArray,Real}}
        buffer = Buffer()
        new(buffer)
    end
end

function upload!(self::TypedBuffer{T},data::Vector{T},usage::GLuint) where {T<:Union{StaticArray,Real}}
    upload!(self._buffer,data,usage)
    deactivate(self)
end

function tSize(self::TypedBuffer{T})::Int where {T<:Union{StaticArray,Real}}
    return sizeof(T)
end

Base.length(self::TypedBuffer)::Int = return length(self._buffer)
activate(self::TypedBuffer) = activate(self._buffer)
deactivate(self::TypedBuffer) = deactivate(self._buffer)
destroy!(self::TypedBuffer) = destroy!(self._buffer)
