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
import ShaderTranspiler

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

include("Helpers/transpilation.jl")
include("Helpers/gpu_tessellation.jl")
include("parametric_tessellation.jl")

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

function _add_and_validate!(element::Any,draw_data::Any,parents::Union{Vector{NodeHandle},Nothing},callback::Union{Function,Nothing},use_main_thread::Bool)::NodeHandle
    global implicitApp
    app::App = implicitApp::App

    needs_lock::Bool = use_main_thread || (parents !== nothing && any(h -> has_geom_flag(app.graph.nodes[h], NODE_EVAL_ON_MAIN), parents))

    if !needs_lock
        handle = add!(app.graph,element,draw_data,parents,callback,zero(UInt64))
        validate!(app.graph,handle,true)
        return handle
    end

    # for pinned nodes, we need the GL context lock, so that the initial eval can make gl* calls
    # for pinned parent nodes, at this stage they cannot be NODE_LOCKED, so add! invalidation can never skip them
    handle, success = @lock app._gl_ctx_lock begin
        h = add!(app.graph,element,draw_data,parents,callback,use_main_thread ? NODE_EVAL_ON_MAIN : zero(UInt64))

        # if a parent got invalidated by add! we have to wait for it, otherwise validate and return asap
        if _ready(app.graph, app.graph.nodes[h])
            validate!(app.graph, h, true)
            (h, true)
        else
            (h, false)
        end
    end
    
    # ?? yielding here helps out with not starving rendering when a burst of lock-needing nodes are added, but keeps add_node! blocking for longer than necessary, do we want this? 
    yield()
    success && return handle

    # if a parent did get invalidated, we wait for the main play! flow to validate it and the new node (add! already ran)
    wait(app.graph.wait_pool, app.graph.nodes[handle], Int(handle.value))

    return handle
end

function add_node!(callback::Function,element::Any;draw_data::Any=nothing,parents::Union{Vector{NodeHandle},Nothing}=nothing,use_main_thread::Bool=false)
    plot()
    return _add_and_validate!(element,draw_data,parents,callback,use_main_thread)
end
function add_node!(callback::Function;draw_data::Any=nothing,parents::Union{Vector{NodeHandle},Nothing}=nothing,use_main_thread::Bool=false)
    plot()
    return _add_and_validate!(nothing,draw_data,parents,callback,use_main_thread)
end
function add_node!(element::Any;draw_data::Any=nothing,parents::Union{Vector{NodeHandle},Nothing}=nothing,use_main_thread::Bool=false)
    plot()
    return _add_and_validate!(element,draw_data,parents,nothing,use_main_thread)
end

# adapter for macro ctor signature
function _add_node!(callback::Function,parents::Vector{NodeHandle};draw_data::Any=nothing,use_main_thread::Bool=false)
    plot()
    # ?? is there a reason this didn't get the same validate! treatment as the other add_node!-s methods?
    # global implicitApp
    # app::App = implicitApp::App
    # value = if parents === nothing
    #     callback()
    # else
    #     arguments = [convert_callback_entry(get_element(handle)) for handle in parents]
    #     callback(arguments...)
    # end
    # return add!(app.graph,value,draw_data,parents,callback,use_main_thread ? NODE_EVAL_ON_MAIN : UInt64(0))
    return _add_and_validate!(nothing,draw_data,parents,callback,use_main_thread)
end
macro add_node!(callback::Expr, args...)
    (positional_args, kw_args) = _parse_macro_arguments((), (:draw_data, :use_main_thread), args...)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, _add_node!, positional_args, kw_args)
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

export plot, add_node!, @add_node!, get_element

end