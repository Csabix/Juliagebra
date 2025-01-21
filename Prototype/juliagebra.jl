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

include("source/abstracts.jl")

include("source/shared_data.jl")
include("source/glfw_data.jl")
include("source/peripherals.jl")
include("source/camera.jl")
include("source/gizmo.jl")
include("source/algebra_logic.jl")
include("source/opengl_data.jl")
include("source/imgui_data.jl")


include("source/base.jl")

include("source/app.jl")

end