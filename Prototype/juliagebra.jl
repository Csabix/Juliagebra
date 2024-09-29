#All files are imported here to prevent circle includes.

module JuliAgebra

include("helpers/macros.jl")
export @connect

include("source/manager.jl")
export Manager 
export run!

include("source/opengl_glfw_control.jl")
export OpenGLGLFWController

include("source/logic_control.jl")
export JuiliAgebraLogicsController

end