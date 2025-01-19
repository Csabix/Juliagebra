#All files are imported here to prevent circle includes.

module JuliAgebra

include("source/GL/gl.jl")

include("source/GLM/glm.jl")

include("source/events.jl")

using GLFW
using ModernGL
using CImGui
using DataStructures
# using StaticArrays

include("source/AlgebraObjects/abstracts.jl")

include("source/shared_data.jl")
include("source/glfw_data.jl")
include("source/peripherals.jl")
include("source/gizmo.jl")
include("source/camera.jl")
include("source/algebra_logic.jl")
include("source/opengl_data.jl")
include("source/imgui_data.jl")

include("source/AlgebraObjects/bodies.jl")
include("source/AlgebraObjects/points.jl")

include("source/app.jl")

# TODO: rethink this export sometime in the future.
export Vec3F

end