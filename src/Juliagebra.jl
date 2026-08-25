module Juliagebra

using ModernGL
using JuliaGLM
using LinearAlgebra
using GLFW
using CImGui
using ImPlot
using DataStructures
using ThreadPinning
using BitFlags
#pinthreads(:cores)
import MacroTools

include("logger.jl")
include("profiling.jl")
include("performance_metrics.jl")

include("asset_watcher.jl")

include("GL/gl.jl")


include("commons.jl")

include("glfw_data.jl")

include("camera.jl")
include("camera_manipulator.jl")

include("Renderers/renderers.jl")

include("abstracts.jl")
include("App/enums.jl")

# Forward-declare typed globals before any file references them (Julia 1.11 typed globals requirement)
global implicitApp::Union{AppDNA,Nothing} = nothing
global _task::Any = nothing

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

include("Graph/graph.jl")

# ? ---------------------------------
# ! Primitives
# ? ---------------------------------

include("Primitives/primitives.jl")
include("Primitives/primitive_intersections.jl")
include("Primitives/primitive_constructors.jl")

# ? ---------------------------------
# ! Model
# ? ---------------------------------

#include("Model/model.jl")
#include("Dependents/extra_model_abstracts.jl")

# ? ---------------------------------
# ! LBVH
# ? ---------------------------------

include("LBVH/aabb.jl")
include("LBVH/morton_codes.jl")
include("LBVH/lbvh.jl")
include("LBVH/lbvh_cache.jl")

const ID_LOWER_BOUND::Int = 3

# ? ---------------------------------
# ! Widgets
# ? ---------------------------------

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

#include("Widgets/points_window.jl")
#include("Widgets/curves_window.jl")
#include("Widgets/surfaces_window.jl")

include("global_dependent_optimizer.jl")

include("Widgets/Windows/gui_dependents_window.jl")
#include("Widgets/Windows/graph_window.jl")
include("Widgets/Windows/property_window.jl")

include("imgui_data.jl")

include("app.jl")

function plot()::Nothing
    global implicitApp
    if implicitApp === nothing
        implicitApp = App()
        init!(implicitApp)
        global _task
        _task = ThreadPinning.@spawnat 1 begin
            play!(implicitApp)
            _task = nothing
            println("ThreadID($(Threads.threadid())): App Ended!")
        end
        errormonitor(_task)
    end
    return nothing
end

function get_element(handle::NodeHandle)::Any
    global implicitApp
    if implicitApp === nothing throw("No active window") end
    app::App = implicitApp::App
    return app.graph.elements[handle]
end

function add_node!(callback::Function,element::Any;draw_data::Any=nothing,parents::Union{Vector{NodeHandle},Nothing}=nothing)
    plot()
    global implicitApp
    app::App = implicitApp::App
    return add!(app.graph,element,draw_data,parents,callback,UInt64(0))
end
function add_node!(callback::Function;draw_data::Any=nothing,parents::Union{Vector{NodeHandle},Nothing}=nothing)
    plot()
    global implicitApp
    app::App = implicitApp::App
    value = if parents === nothing
        callback()
    else
        arguments = [convert_callback_entry(get_element(handle)) for handle in parents]
        callback(arguments...)
    end
    return add!(app.graph,value,draw_data,parents,callback,UInt64(0))
end
function add_node!(element::Any;draw_data::Any=nothing)
    plot()
    global implicitApp
    app::App = implicitApp::App
    return add!(app.graph,element,draw_data,nothing,nothing,UInt64(0))
end

function Wait()
    global _task
    if _task === nothing return end
    wait(_task)
end

function Base.show(io::IO, handle::NodeHandle)
    if implicitApp !== nothing && checkbounds(Bool, implicitApp.graph.elements, handle.value)
        print(io, "NodeHandle(value=$(handle.value),")
        show(io, implicitApp.graph.elements[handle.value])
        print(io, ")")
    else
        print(io, "NodeHandle(value=$(handle.value),INVALID LOCATION)")
    end
end

include("Dependents/dependents.jl")
include("Helpers/geometric_helpers.jl")
include("Primitives/geometric_functions.jl")

export plot, add_node!, get_element

end