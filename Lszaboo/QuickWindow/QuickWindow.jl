module QuickWindow

include("WindowManager.jl")
include("GraphicsAccelelators/OpenGL/OpenGlAccelerator.jl")
include("WindowBackends/GLFWBackend.jl")

export WindowManager
export GLFWBackend
export OpenGLAccelerator
export mainLoop!

end