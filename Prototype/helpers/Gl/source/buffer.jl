
mutable struct Buffer <:OpenGLWrapper
    _id::GLuint
    _usage::GLuint
    _numOfItems::Int

    function Buffer(usage::GLuint)
        id = Ref{GLuint}(0)
        glGenBuffers(1,id)
        id = id[]
        self = new(id,usage,0)
        upload!(self,[])

        return self
    end
end

function upload!(self::Buffer,data::Vector)
    self._numOfItems = length(data)
    glBindBuffer(GL_ARRAY_BUFFER,self._id)
    
    if length(data) > 0
        @assert isbitstype(eltype(data)) "Input array for Buffer upload is not contiguous in memory"
        #println(reinterpret(Float32, data))
        #println(self._id)
    end

    glBufferData(GL_ARRAY_BUFFER,sizeof(data),data,self._usage)
    #println("$(sizeof(data)) - $(length(data))")
    
end

upload!(self::Buffer,data::Vector,usage::GLuint) = (self._usage = usage;update!(self,data))
activate(self::Buffer) = glBindBuffer(GL_ARRAY_BUFFER,self._id)
delete!(self::Buffer) = glDeleteBuffers(1,[self._id])
draw(mode::GLuint,length::Int) = glDrawArrays(mode,0,length)
draw(self::Buffer,mode::GLuint) = draw(mode,self._numOfItems) 

export Buffer, upload!, activate, delete!, draw