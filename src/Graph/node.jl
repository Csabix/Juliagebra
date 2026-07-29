const NodeHandle::DataType = UInt32
const NodeState::DataType = UInt64
const NodeFlag::DataType = UInt64

const NODE_VALID::NodeState = NodeState(0x0)
const NODE_LOCKED::NodeState = NodeState(0x1)
const NODE_INVALID::NodeState = NodeState(0x2)

const _NODE_BIT_SHIFT = Ref(0)
macro node_bit(name::Symbol)
    if _NODE_BIT_SHIFT[] >= sizeof(UInt64) * 8
        error("Maximum of $(sizeof(UInt64) * 8) node bits reached!")
    end
    value::NodeFlag = one(NodeFlag) << _NODE_BIT_SHIFT[]
    _NODE_BIT_SHIFT[] += 1
    return quote
        const $(esc(name))::NodeFlag = $(esc(value))
    end
end

mutable struct GeometryPlotNode
    @atomic state::NodeState
    parent_h::Union{Vector{NodeHandle},Nothing}
    child_h::Union{Vector{NodeHandle},Nothing}
    callback::Union{Function,Nothing}
    flags::NodeFlag

    GeometryPlotNode(callback::Union{Function,Nothing}, parent_h::Union{Vector{NodeHandle},Nothing}, flags::NodeFlag) =
        new(isnothing(callback) ? NODE_VALID : NODE_INVALID, parent_h, nothing, callback, flags)
end

update(element::Any,delta_time::Float64)::Tuple{Any,Bool} = (element,false)
convert_callback_entry(element::Any)::Any = element
convert_callback_result(element::Any, result::Any)::Any = result
eval_node(element::Any, callback::Function, arguments::Vector{Any})::Any = callback(arguments...)
render_node(element::Any, renderers::Dict{DataType,Renderer}, id::UInt32)::Nothing = nothing
render_node_gui(element::Any)::Tuple{Any,Bool} = element, false
edit_node(element::Any, renderers::Dict{DataType,Renderer},handle::NodeHandle)::Tuple{Any,Bool} = (element,false)
edit_node_overload(element::Any)::Bool = false

on_gizmo_select(element::Any)::Tuple{UInt32,Vec3D,Any} = (AXIS_NONE, Vec3DNan, nothing) # Used gizmo axes, gizmo position, data
on_gizmo_move(element::Any, position::Vec3D, data::Any)::Tuple{Any,Any} = (element, nothing)

function eval_geometry_node(element::Any, node::GeometryPlotNode, elements::Vector{Any})
    arguments::Vector{Any} = if node.parent_h === nothing
        Any[]
    else
        Any[convert_callback_entry(elements[p_h]) for p_h in node.parent_h]
    end
    callback_result::Any = eval_node(element, node.callback, arguments)
    return convert_callback_result(element, callback_result)
end

export update, convert_callback_entry, convert_callback_result, eval_node, render_node, render_node_gui, edit_node, edit_node_overload
export on_gizmo_select, on_gizmo_move
export eval_geometry_node, GeometryPlotNode