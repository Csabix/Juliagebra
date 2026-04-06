# ? ---------------------------------
# ! VertexArray
# ? ---------------------------------

struct VertexAttrib
    Iformat::Bool
    size::GLint
    type::GLenum
    normalized::GLboolean
    offset::GLuint
end

struct VertexArray <: OpenGLWrapper
    _id::GLuint
    
    function VertexArray()
        id = Ref{GLuint}()
        glCreateVertexArrays(1,id)
        return new(id[])
    end
end

function bind_buffers!(self::VertexArray,buffers::AbstractVector{<:BufferBase})
    index = 0
    for (i,buffer) in enumerate(buffers)
        new_index = _vertexAttribs(self._id,index,buffer)
        glVertexArrayVertexBuffer(self._id,i-1,id(buffer),0,sizeof(eltype(buffer)))
        for j in index:new_index-1
            glVertexArrayAttribBinding(self._id, j, i-1)
        end
        index = new_index 
    end
end

function bind_buffers!(self::VertexArray,buffers,attributes)
    index = 0
    for (i,buffer) in enumerate(buffers)
        if isnothing(attributes[i])
            new_index = _vertexAttribs(self._id,index,buffer)
            for j in index:new_index-1
                glVertexArrayAttribBinding(self._id, j, i-1)
            end
            index = new_index 
        else
            for attribute in attributes[i]
                glEnableVertexArrayAttrib(self._id, index)
                if attribute.Iformat
                    glVertexArrayAttribIFormat(self._id,index,attribute.size,attribute.type,attribute.offset)
                else
                    glVertexArrayAttribFormat(self._id,index,attribute.size,attribute.type,attribute.normalized,attribute.offset)
                end
                glVertexArrayAttribBinding(self._id, index, i-1)
                index += 1
            end
        end
        glVertexArrayVertexBuffer(self._id,i-1,id(buffer),0,sizeof(eltype(buffer)))
    end
end

bind_ebo!(self::VertexArray,buffer::BufferBase) = glVertexArrayElementBuffer(self._id,id(buffer))
rebind_buffer!(self::VertexArray, index::Int, buffer::BufferBase) = glVertexArrayVertexBuffer(self._id,index-1,id(buffer),0,sizeof(eltype(buffer)))
rebind_ebo!(self::VertexArray,buffer::BufferBase) = glVertexArrayElementBuffer(self._id,id(buffer))

destroy!(self::VertexArray) = glDeleteVertexArrays(1,[self._id])
activate(self::VertexArray)::Nothing = glBindVertexArray(self._id)::Nothing

"""
Function to create a vertexAttribFormat.

# Arguments:
- `vao`    -> vertex array buffer object
- `index`  -> layout(location = index)
- `atype`  -> The type of the attribute data (Float32, Vec3 ...)
- `stride` -> how mutch to jump to find the start of the next element for all this attribute
- `offset` -> offset in bytes inside 1 stride

# For example see:

If data is stored in an array like:

`[vec3,vec2,float,vec3,vec2,float,vec3,vec2,float...]`

If `vec3`, `vec2`, `float` is 1 big element in a buffer, then `layout (location = 0)` is `vec3`, `1` is `vec2`, `2` is `float`.
`index` is for layout, `atype` for `vec3`,`vec2`,`float`. `stride` must be `sizeof(vec3)+sizeof(vec2)+sizeof(float)` and `offset` must be
`0` for `vec3`, `sizeof(vec3)` for `vec2`, `sizeof(vec3) + sizeof(vec2)` for `float`.

"""
function _vertexAttrib(vao::GLuint, index::Int, atype::DataType, stride::Int = sizeof(atype), offset::UInt = UInt(0))
    #get number of components (3 for vec3)
    size::GLint = atype <: StaticArray ? length(atype) : 1
    @assert 1<=size<=4 "invalid vertex attrib size"
    elem::DataType = atype <: StaticArray ? eltype(atype) : atype
    @assert haskey(JuliaType2OpenGL,elem) "invalid base type for vertex"
    type::GLenum = JuliaType2OpenGL[elem]                       # dictionary
    normalized::GLenum = elem <: Integer ? GL_TRUE : GL_FALSE   # normalized by default
    glEnableVertexArrayAttrib(vao,GLuint(index))
    #stride needs to be converted into GLsizei type | pointer to offset (where the pointer doesnt know tha data it's reffering to, hence why Nothing is passed)    
    glVertexArrayAttribFormat(vao,GLuint(index),size,type,normalized,offset)
end

function _vertexAttribs(vao::GLuint,index::Int,buffer::BufferBase)::Int
    vtype = eltype(buffer)
    if vtype <: StaticArray || vtype <: Real
        _vertexAttrib(vao,index,vtype)
        index += 1
    else
        stride::Int = sizeof(vtype)
        for type in vtype.types
            # fieldoffset tells the byte offset of the i-th type in vtype.
            _vertexAttrib(vao,index,type,stride,UInt(fieldoffset(vtype,i)))
            index += 1
        end
    end
    return index
end