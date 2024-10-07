#All files are imported here to prevent circle includes.

module JuliAgebra

include("helpers/Macros/source/macros.jl")

include("helpers/Gl/source/gl.jl")
using .Gl

include("helpers/Glm/source/glm.jl")
using .Glm

include("helpers/Events/source/events.jl")
using .Events

include("source/manager.jl")

include("source/opengl_glfw_control.jl")

include("source/logic_control.jl")

end