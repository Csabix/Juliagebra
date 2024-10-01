#All files are imported here to prevent circle includes.

module JuliAgebra

using ModernGL
using GLFW

include("helpers/Macros/source/macros.jl")

include("helpers/Gl/source/gl.jl")
using .Gl

include("helpers/Glm/source/glm.jl")
using .Glm

include("source/manager.jl")
export Manager 
export run!

include("source/opengl_glfw_control.jl")
export OpenGLGLFWController

include("source/logic_control.jl")
export JuiliAgebraLogicsController

end