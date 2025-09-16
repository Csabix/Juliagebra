# ? ---------------------------------
# ! VertexArray
# ? ---------------------------------

mutable struct VertexArray <: OpenGLWrapper
    _id::GLuint
    
    function VertexArray(itemType::DataType)
        id = Ref{GLuint}(0)
        glGenVertexArrays(1,id)
        id = id[]
        self = new(id)
        
        activate(self)
        _vertexAttribs(itemType)
        return self
    end

    function VertexArray(buffers::Tuple{Vararg{TypedBuffer}})
        id = Ref{GLuint}(0)
        glGenVertexArrays(1,id)
        id = id[]
        self = new(id)

        activate(self)

        stride = 0
        for buffer in buffers
            stride += tSize(buffer)
        end

        index = 0
        offset = UInt(0)
        for buffer in buffers
            offset += _vertexAttribs(index,buffer,stride,offset)
            index += 1
        end
        deactivate(buffers[1])

        return self
    end
end
destroy!(x::VertexArray) = glDeleteVertexArrays(1,[x._id])
activate(vao::VertexArray) = glBindVertexArray(vao._id)

const JuliaType2OpenGL = Dict([
    Float16 => GL_HALF_FLOAT,
    Float32 => GL_FLOAT,
    Float64 => GL_DOUBLE,
    Int8    => GL_BYTE,
    Int16   => GL_SHORT,
    Int32   => GL_INT,
    UInt8   => GL_UNSIGNED_BYTE,
    UInt16  => GL_UNSIGNED_SHORT,
    UInt32  => GL_UNSIGNED_INT,
])

"""
Function to create a vertexAttribPointer.

# Arguments:
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
function _vertexAttrib(index::Int, atype::DataType, stride::Int = sizeof(atype), offset::UInt = UInt(0))
    #get number of components (3 for vec3)
    size::GLint = atype <: StaticArray ? length(atype) : 1
    @assert 1<=size<=4 "invalid vertex attrib size"
    elem::DataType = atype <: StaticArray ? eltype(atype) : atype
    @assert 1<=sizeof(elem)<=8 "invalid base type for vertex"
    type::GLenum = JuliaType2OpenGL[elem]                       # dictionary
    normalized::GLenum = elem <: Integer ? GL_TRUE : GL_FALSE   # normalized by default
    glEnableVertexAttribArray(GLuint(index))
    #stride needs to be converted into GLsizei type | pointer to offset (where the pointer doesnt know tha data it's reffering to, hence why Nothing is passed)    
    glVertexAttribPointer(GLuint(index),size,type,normalized,GLsizei(stride),Ptr{Nothing}(offset))
    
    #println("\tglVertexAttribPointer(index=$index,size=$size,type=$type,normalized=$normalized,stride=$stride,offset=$offset)");
end

"""
Shorter function to automatically create a vertexAttribPointer from arguments.

# Arguments:
- `vtype` -> could be a single type, like vec3 or it could be a complex struct type.

"""
function _vertexAttribs(vtype::DataType,index::Int = 0)
    if vtype <: StaticArray || vtype <: Real
        _vertexAttrib(index,vtype)
    else
        stride::Int = sizeof(vtype)
        ltypes = vtype.types
        for i in eachindex(ltypes)
            # fieldoffset tells the byte offset of the i-th type in vtype.
            _vertexAttrib(i-1 + index,ltypes[i],stride,UInt(fieldoffset(vtype,i)))
        end
    end
end

function _vertexAttribs(index::Int,buffer::TypedBuffer{T},stride::Int,offset::UInt)::UInt where {T<:Union{StaticArray,Real}}
    activate(buffer)
    _vertexAttrib(index,T)
    return UInt(sizeof(T))
end