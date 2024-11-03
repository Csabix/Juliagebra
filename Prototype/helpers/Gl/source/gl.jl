module Gl

import Base.length
using StaticArrays, ModernGL

abstract type OpenGLWrapper end

activate(x::OpenGLWrapper) = error("not implemented for $typeof(x)")
deleat!(x::OpenGLWrapper) = error("not implemented for $typeof(x)")

export deleat!, activate

include("buffer.jl")
include("vertex_array.jl")
include("uniforms.jl")
include("shader.jl")
include("texture.jl")
include("frame_buffer.jl")

end