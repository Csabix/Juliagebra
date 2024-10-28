#All files are imported here to prevent circle includes.

module JuliAgebra

include("helpers/Macros/source/macros.jl")

include("helpers/Gl/source/gl.jl")
using .Gl

include("helpers/Glm/source/glm.jl")
using .Glm


include("helpers/Events/source/events.jl")
using .Events

using GLFW
using ModernGL
using DataStructures

include("source/manager_containers/shared_data.jl")
include("source/manager_containers/glfw_data.jl")
include("source/manager_containers/opengl_data.jl")




include("source/algebra_logic.jl")
include("source/AlgebraObjects/bodies.jl")



include("source/window_manager.jl")

# TODO: rethink this export sometime in the future.
import .Glm:Vec3
export Vec3

end