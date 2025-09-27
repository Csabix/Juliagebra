# ! All files should be imported here to prevent circular includes.

module Juliagebra

include("logger.jl")

include("GL/gl.jl")

#include("GLM/glm.jl")

using JuliaGLM

include("events.jl")

using LinearAlgebra
using GLFW
using ModernGL
using CImGui
using DataStructures

include("commons.jl")

include("abstracts.jl")

# ? ---------------------------------
# ! Helpers
# ? ---------------------------------

include("Helpers/flat_matrix_manager.jl")
include("Helpers/flat_matrix.jl")
include("Helpers/queuelock.jl")
include("Helpers/collector.jl")
include("Helpers/imgui_helpers.jl")

ID_LOWER_BOUND = 3

include("shared_data.jl")

include("glfw_data.jl")

include("peripherals.jl")

include("camera.jl")

# ? ---------------------------------
# ! Widgets
# ? ---------------------------------

include("Widgets/widget.jl")
include("Widgets/opengl_widget.jl")
include("Widgets/imgui_widget.jl")
include("Widgets/dock.jl")
include("Widgets/window.jl")
include("Widgets/gui_dependents_window.jl")
include("Widgets/data_peeker.jl")
include("Widgets/console.jl")
include("Widgets/named_window.jl")

include("Widgets/gizmo.jl")
include("Widgets/ortho_gizmo.jl")

include("opengl_data.jl")

include("imgui_data.jl")

include("plans.jl")

# ? ---------------------------------
# ! Dependents
# ? ---------------------------------

include("Dependents/dependent_chain.jl")
include("Dependents/dependent_graph.jl")
include("Dependents/dependent.jl")
include("Dependents/dependent_observer.jl")
include("Dependents/observed_dependent.jl")
include("Dependents/dependent_renderer.jl")
include("Dependents/rendered_dependent.jl")
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