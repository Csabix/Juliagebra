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

include("source/commons.jl")

include("source/abstracts.jl")

ID_LOWER_BOUND = 3

include("source/shared_data.jl")
include("source/glfw_data.jl")
include("source/peripherals.jl")
include("source/camera.jl")
include("source/gizmo.jl")
include("source/algebra_logic.jl")
include("source/opengl_data.jl")
include("source/imgui_data.jl")

include("source/plans.jl")

include("source/queuelock.jl")

include("source/renderers.jl")

include("source/algebra.jl")

include("source/point.jl")

include("source/base.jl")

include("source/app.jl")

end