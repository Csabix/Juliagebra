# ! All files should be imported here to prevent circular includes.

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

# ? ---------------------------------
# ! Helpers
# ? ---------------------------------

include("source/Helpers/flat_matrix_manager.jl")
include("source/Helpers/flat_matrix.jl")
include("source/Helpers/queuelock.jl")

ID_LOWER_BOUND = 3

include("source/shared_data.jl")

include("source/glfw_data.jl")

include("source/peripherals.jl")

include("source/camera.jl")

# ? ---------------------------------
# ! Widgets
# ? ---------------------------------

include("source/Widgets/gizmo.jl")
include("source/Widgets/ortho_gizmo.jl")

include("source/dependent_graph.jl")

include("source/opengl_data.jl")

include("source/imgui_data.jl")

include("source/plans.jl")

include("source/dependent.jl")

include("source/renderers.jl")

include("source/rendered_algebra.jl")

# ? ---------------------------------
# ! Dependents
# ? ---------------------------------

include("source/Dependents/point.jl")
include("source/Dependents/curve.jl")
# include("source/Dependents/mesh.jl")
include("source/Dependents/surface.jl")
include("source/Dependents/primitives.jl")
include("source/Dependents/primitive_intersections.jl")
include("source/Dependents/intersections.jl")

include("source/app.jl")

include("source/constructors.jl")

include("source/LBVH/aabb.jl")
#include("source/LBVH/morton_codes.jl")
include("source/LBVH/lbvh.jl")

end