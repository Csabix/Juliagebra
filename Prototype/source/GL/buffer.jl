
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
    if length(data) > 0
        @assert isbitstype(eltype(data)) "Input array for Buffer upload is not contiguous in memory"
        #println(reinterpret(Float32, data))
        #println(self._id)
    end
    glBufferData(GL_ARRAY_BUFFER,sizeof(data),data,usage)
    #println("$(sizeof(data)) - $(length(data))")
end

activate(self::Buffer) = glBindBuffer(GL_ARRAY_BUFFER,self._id)
deactivate(self::Buffer) = glBindBuffer(GL_ARRAY_BUFFER,0)
destroy!(self::Buffer) = glDeleteBuffers(1,[self._id])


