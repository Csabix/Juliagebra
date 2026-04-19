# ! All files should be imported here to prevent circular includes.

module Juliagebra

include("logger.jl")

include("GL/gl.jl")

using JuliaGLM

include("events.jl")

using LinearAlgebra
using GLFW
using ModernGL
using CImGui
using DataStructures
using ThreadPinning
#pinthreads(:cores)
import MacroTools

include("performance_metrics.jl")

include("commons.jl")

include("abstracts.jl")

# ? ---------------------------------
# ! Helpers
# ? ---------------------------------

include("Helpers/flat_matrix_manager.jl")
include("Helpers/flat_matrix.jl")
include("Helpers/queuelock.jl")
include("Helpers/imgui_helpers.jl")
include("Helpers/infer.jl")
include("Helpers/dependency_lookup.jl")

# ? ---------------------------------
# ! Primitives
# ? ---------------------------------

include("Primitives/primitives.jl")
include("Primitives/primitive_intersections.jl")
include("Primitives/primitive_constructors.jl")

# ? ---------------------------------
# ! LBVH
# ? ---------------------------------

include("LBVH/aabb.jl")
include("LBVH/morton_codes.jl")
include("LBVH/lbvh.jl")
include("LBVH/lbvh_cache.jl")

const ID_LOWER_BOUND::Int = 3

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

include("Widgets/data_peeker.jl")
include("Widgets/console.jl")
include("Widgets/named_window.jl")
include("Widgets/performance_viewer.jl")
include("Widgets/graph_viewer_window.jl")
include("Widgets/points_window.jl")

include("Widgets/gizmo.jl")
include("Widgets/ortho_gizmo.jl")


include("Renderers/renderers.jl")
include("opengl_data.jl")

# ? ---------------------------------
# ! Dependents
# ? ---------------------------------

include("GraphCore/dependent_chain.jl")
include("GraphCore/dependent_graph.jl")
include("GraphCore/dependent.jl")
include("GraphCore/dependent_observer.jl")
include("GraphCore/value_holder.jl")
include("GraphCore/generic_value_holder.jl")
include("GraphCore/source_value_holder.jl")
#include("GraphCore/unary_value_holder.jl")
include("GraphCore/observed_dependent.jl")


include("Dependents/dependents.jl")

# TODO: Continue this.
include("GraphCore/observer_pool.jl")
include("synchronizer.jl")
include("Widgets/gui_dependents_window.jl")

include("global_dependent_optimizer.jl")

include("imgui_data.jl")
include("app.jl")

end