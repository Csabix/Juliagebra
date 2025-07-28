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
include("source/ortho_gizmo.jl")
include("source/dependent_graph.jl")
include("source/opengl_data.jl")
include("source/imgui_data.jl")

include("source/flat_matrix_manager.jl")

include("source/flat_matrix.jl")

include("source/plans.jl")

include("source/undef.jl")

include("source/algebra.jl")

include("source/queuelock.jl")

include("source/renderers.jl")

include("source/rendered_algebra.jl")

include("source/point.jl")

include("source/curve.jl")

# include("source/mesh.jl")

include("source/surface.jl")

include("source/intersections.jl")

include("source/base.jl")

include("source/app.jl")

include("source/constructors.jl")

end