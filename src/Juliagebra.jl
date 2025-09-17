# ! All files should be imported here to prevent circular includes.

module Juliagebra

include("GL/gl.jl")

include("GLM/glm.jl")

include("events.jl")

using GLFW
using ModernGL
using CImGui
using DataStructures
# using StaticArrays

include("commons.jl")

include("abstracts.jl")

# ? ---------------------------------
# ! Helpers
# ? ---------------------------------

include("Helpers/flat_matrix_manager.jl")
include("Helpers/flat_matrix.jl")
include("Helpers/queuelock.jl")
include("Helpers/collector.jl")

ID_LOWER_BOUND = 3

include("shared_data.jl")

include("glfw_data.jl")

include("peripherals.jl")

include("camera.jl")

# ? ---------------------------------
# ! Widgets
# ? ---------------------------------

include("Widgets/gizmo.jl")
include("Widgets/ortho_gizmo.jl")

include("dependent_graph.jl")

include("opengl_data.jl")

include("imgui_data.jl")

include("plans.jl")

include("dependent.jl")

include("renderers.jl")

include("rendered_algebra.jl")

# ? ---------------------------------
# ! Dependents
# ? ---------------------------------

include("Dependents/point.jl")
include("Dependents/curve.jl")
# include("Dependents/mesh.jl")
include("Dependents/surface.jl")
include("Dependents/primitives.jl")
include("Dependents/primitive_intersections.jl")
include("Dependents/intersections.jl")

include("app.jl")

include("constructors.jl")

# ? ---------------------------------
# ! LBVH
# ? ---------------------------------

include("LBVH/aabb.jl")
include("LBVH/morton_codes.jl")
include("LBVH/lbvh.jl")

end