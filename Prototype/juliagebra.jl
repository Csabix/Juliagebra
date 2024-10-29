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
# using StaticArrays

include("source/shared_data.jl")
include("source/glfw_data.jl")
include("source/opengl_data.jl")
include("source/AlgebraObjects/bodies.jl")
include("source/algebra_logic.jl")

include("source/window_manager.jl")

# TODO: rethink this export sometime in the future.
import .Glm:Vec3
export Vec3

end