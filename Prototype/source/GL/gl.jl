import Base.length
using StaticArrays, ModernGL

abstract type OpenGLWrapper end

activate(x::OpenGLWrapper) = error("not implemented for $typeof(x)")
destroy!(x::OpenGLWrapper) = error("not implemented for $typeof(x)")

include("buffer.jl")
include("vertex_array.jl")
include("buffer_array.jl")
include("uniforms.jl")
include("shader.jl")
include("texture.jl")
include("frame_buffer.jl")