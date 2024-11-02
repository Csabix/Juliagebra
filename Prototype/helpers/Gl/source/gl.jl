module Gl

import Base.length
using StaticArrays, ModernGL

abstract type OpenGLWrapper end

activate(x::OpenGLWrapper) = error("not implemented for $typeof(x)")
destroy!(x::OpenGLWrapper) = error("not implemented for $typeof(x)")

export destroy!, activate

include("buffer.jl")
include("vertex_array.jl")
include("shader.jl")
include("texture.jl")
include("frame_buffer.jl")

end