# ! All files should be imported here to prevent circular includes.

module Juliagebra

include("asset_watcher.jl")
include("logger.jl")

include("GL/gl.jl")

using JuliaGLM

using LinearAlgebra
using GLFW
using ModernGL
using CImGui
using ImPlot
using DataStructures
using ThreadPinning
using BitFlags
#pinthreads(:cores)
import MacroTools

include("profiling.jl")
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
include("Helpers/times.jl")

# ? ---------------------------------
# ! Primitives
# ? ---------------------------------

include("Primitives/primitives.jl")
include("Primitives/primitive_intersections.jl")
include("Primitives/primitive_constructors.jl")

# ? ---------------------------------
# ! Model
# ? ---------------------------------

include("Model/model.jl")
include("Dependents/extra_model_abstracts.jl")

# ? ---------------------------------
# ! LBVH
# ? ---------------------------------

include("LBVH/aabb.jl")
include("LBVH/morton_codes.jl")
include("LBVH/lbvh.jl")
include("LBVH/lbvh_cache.jl")

const ID_LOWER_BOUND::Int = 3

include("glfw_data.jl")

include("camera.jl")
include("camera_manipulator.jl")

# ? ---------------------------------
# ! Widgets
# ? ---------------------------------
include("Renderers/renderers.jl")
include("Widgets/widget.jl")
include("Widgets/opengl_widget.jl")
include("Widgets/imgui_widget.jl")
include("Widgets/dock.jl")
include("Widgets/window.jl")
include("Widgets/reset_widget.jl")
include("Widgets/options_widget.jl")

include("Widgets/console.jl")
include("Widgets/named_window.jl")
include("Widgets/performance_viewer.jl")
include("Widgets/Windows/frame_time_window.jl")
include("Widgets/Windows/options_window.jl")


include("opengl_data.jl")

include("Widgets/coordinates_widget.jl")

# ? ---------------------------------
# ! Dependents
# ? ---------------------------------

include("Dependents/dependents.jl")

include("Widgets/points_window.jl")
include("Widgets/curves_window.jl")
include("Widgets/surfaces_window.jl")

include("global_dependent_optimizer.jl")

include("Widgets/Windows/gui_dependents_window.jl")
include("Widgets/Windows/graph_window.jl")

include("imgui_data.jl")

include("App/starter.jl")
include("App/commander.jl")
include("styles.jl")
include("app.jl")



end