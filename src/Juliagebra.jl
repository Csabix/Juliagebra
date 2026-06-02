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
include("App/enums.jl")

# Forward-declare typed globals before any file references them (Julia 1.11 typed globals requirement)
global implicitApp::Union{AppDNA,Nothing} = nothing
global greenTask::Union{Any,Nothing} = nothing

# ? ---------------------------------
# ! Helpers
# ? ---------------------------------

include("Generated/LibAssimp.jl")

include("Helpers/flat_matrix_manager.jl")
include("Helpers/flat_matrix.jl")
include("Helpers/imgui_helpers.jl")
include("Helpers/scene.jl")
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
include("Widgets/reset_widget.jl")

include("Widgets/data_peeker.jl")
include("Widgets/console.jl")
include("Widgets/named_window.jl")
include("Widgets/performance_viewer.jl")
include("Widgets/Windows/frame_rate_window.jl")

include("Widgets/gizmo.jl")
include("Widgets/ortho_gizmo.jl")


include("Renderers/renderers.jl")
include("opengl_data.jl")

# ? ---------------------------------
# ! Dependents
# ? ---------------------------------

include("Model/schedule.jl")
include("Model/dependent_graph.jl")
include("Model/dependent.jl")
include("Model/dependent_observer.jl")
include("Model/value_holder.jl")
include("Model/generic_value_holder.jl")
include("Model/source_value_holder.jl")
#include("Model/unary_value_holder.jl")
include("Model/subject_dependent.jl")


include("Dependents/dependents.jl")

include("Widgets/points_window.jl")
include("Widgets/curves_window.jl")
include("Widgets/surfaces_window.jl")

include("global_dependent_optimizer.jl")

#include("Dependents/Gui/gui_renderer.jl")
#include("Dependents/Gui/gui_dependent.jl")
#include("Dependents/Gui/toggle.jl")
#include("Dependents/Gui/slider.jl")
#include("Dependents/Gui/textbox.jl")
#include("Dependents/Gui/stepper.jl")
include("Widgets/Windows/gui_dependents_window.jl")
include("imgui_data.jl")

include("Model/Threads/completed_condition.jl")
include("Model/Threads/goal.jl")
include("Model/Threads/builder.jl")
include("Model/Threads/adder.jl")
include("Model/Threads/synchronizer.jl")
include("Model/Threads/eval_worker.jl")
include("Model/Threads/scheduler.jl")
include("Model/Threads/model.jl")

include("Widgets/Windows/graph_window.jl")

include("App/starter.jl")
include("App/commander.jl")
include("app.jl")



end