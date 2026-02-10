# ? ---------------------------------
# ! Buffer
# ? ---------------------------------


mutable struct Buffer{T} <:OpenGLWrapper
    _id::GLuint
    _numOfItems::Int

    function Buffer{T}() where T
        id = Ref{GLuint}(0)
        glGenBuffers(1,id)
        id = id[]
        self = new(id,0)
        return self
    end
end

Buffer() = Buffer{GL_ARRAY_BUFFER}()

function upload!(self::Buffer{T},data::Vector,usage::GLuint) where T
    glBindBuffer(T,self._id)
    self._numOfItems = length(data)

    if self._numOfItems > 0
        @assert isbitstype(eltype(data)) "Input array for Buffer upload is not contiguous in memory"
        #println(reinterpret(Float32, data))
        #println(self._id)
    end
    glBufferData(T,sizeof(data),data,usage)
    #println("$(sizeof(data)) - $(length(data))")
end

Base.length(self::Buffer)::Int = self._numOfItems
activate(self::Buffer{T}) where T = glBindBuffer(T,self._id)
deactivate(self::Buffer{T}) where T = glBindBuffer(T,0)
destroy!(self::Buffer) = glDeleteBuffers(1,[self._id])


# ? ---------------------------------
# ! TypedBuffer
# ? ---------------------------------

mutable struct TypedBuffer{T}<:OpenGLWrapper where {T<:Union{StaticArray,Real}} 
    _buffer::Buffer

    function TypedBuffer{T}(arrayMode=GL_ARRAY_BUFFER) where {T<:Union{StaticArray,Real}}
        buffer = Buffer{arrayMode}()
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

# ? ---------------------------------
# ! IndexBuffer
# ? ---------------------------------

IndexBuffer() = TypedBuffer{UInt32}(GL_ELEMENT_ARRAY_BUFFER)

# TODO: Implement binding for every buffer.

struct StaticBuffer <:OpenGLWrapper
    _id::GLuint
    _size::GLsizeiptr
    _numOfItems::Int

    function StaticBuffer(id=0,size=0,numOfItems=0)
        return new(id,size,numOfItems)
    end
end

function create(self::StaticBuffer,size::GLsizeiptr,flags::GLuint)::StaticBuffer
    if self._id != 0 glDeleteBuffers(1,[self._id]) end
    id = Ref{GLuint}(0)
    glCreateBuffers(1,id)

    glNamedBufferStorage(id[],size,C_NULL,flags)

    return StaticBuffer(id[],size)
end

function create(self::StaticBuffer,data::Vector,flags::GLuint)::StaticBuffer
    @assert isbitstype(eltype(data)) "Input array for Buffer upload is not contiguous in memory"

    if self._id != 0 glDeleteBuffers(1,[self._id]) end
    id = Ref{GLuint}(0)
    glCreateBuffers(1,id)

    numOfItems::Int = length(data)
    size::GLsizeiptr = sizeof(data)
    glNamedBufferStorage(id[],size,data,flags)
    return StaticBuffer(id[],size,numOfItems)
end

function upload!(self::StaticBuffer,data::Vector)
    @assert isbitstype(eltype(data)) "Input array for Buffer upload is not contiguous in memory"
    if sizeof(data) > self._size
        @log "Imput data is larger than the size of StaticBuffer, create a new StaticBuffer for the data" ERR
    end

    glNamedBufferSubData(self._id,0,sizeof(data),data)
end

Base.length(self::StaticBuffer)::Int = self._numOfItems
bind(self::StaticBuffer, target::GLuint) = glBindBuffer(target, self._id)
bind_ssbo(self::StaticBuffer, index) = glBindBufferBase(GL_SHADER_STORAGE_BUFFER,index,self._id)
destroy!(self::StaticBuffer) = if self._id != 0 glDeleteBuffers(1,[self._id]) end