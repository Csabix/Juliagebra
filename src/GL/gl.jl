import Base.length
using StaticArrays, ModernGL

abstract type OpenGLWrapper end

activate(x::OpenGLWrapper)::Nothing = error("not implemented for $typeof(x)")
destroy!(x::OpenGLWrapper) = error("not implemented for $typeof(x)")

const JuliaType2OpenGL = IdDict(
    Float16 => GL_HALF_FLOAT,
    Float32 => GL_FLOAT,
    Float64 => GL_DOUBLE,
    Int8    => GL_BYTE,
    Int16   => GL_SHORT,
    Int32   => GL_INT,
    UInt8   => GL_UNSIGNED_BYTE,
    UInt16  => GL_UNSIGNED_SHORT,
    UInt32  => GL_UNSIGNED_INT
)

include("buffer.jl")
include("vertex_array.jl")
include("buffer_array.jl")
include("uniforms.jl")
include("shader.jl")
include("texture.jl")
include("frame_buffer.jl")