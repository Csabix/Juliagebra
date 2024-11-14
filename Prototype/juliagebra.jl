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

abstract type AlgebraObject end
abstract type RenderPlan end
abstract type RenderEmployee end

include("source/shared_data.jl")
include("source/glfw_data.jl")
include("source/peripherals.jl")
include("source/camera.jl")
include("source/algebra_logic.jl")
include("source/opengl_data.jl")
include("source/imgui_data.jl")
include("source/AlgebraObjects/bodies.jl")


include("source/window_manager.jl")

# TODO: rethink this export sometime in the future.
export Vec3T

end