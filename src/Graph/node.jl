struct NodeHandle value::UInt32 end
Base.to_index(handle::NodeHandle)::Int = Int(handle.value)

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
render_node(element::Any, data::Any, renderers::Dict{DataType,Renderer}, id::UInt32)::Any = data
render_node_gui(element::Any)::Tuple{Any,Bool} = element, false

const EDIT_NODE_NONE::Int = 0
const EDIT_NODE_RERENDER::Int = 1
const EDIT_NODE_INVALIDATE::Int = 2
function edit_node(element::Any, render_data::Any, renderers::Dict{DataType,Renderer},handle::NodeHandle)::Tuple{Any,Any,Int}
    result::Int = EDIT_NODE_NONE
    result, element = modify_properties(element, handle, EDIT_NODE_INVALIDATE)
    CImGui.Separator()
    CImGui.Text("Render Data")
    result, render_data = modify_properties(render_data, handle, EDIT_NODE_RERENDER)
    if result & EDIT_NODE_RERENDER != 0
        rerender_node(render_data, renderers, handle)
    end
    return element, render_data, result
end

@enum PropertyHint begin
    PROPERTY_HINT_NONE
    PROPERTY_HINT_COLOR
    PROPERTY_HINT_COLOR_ALPHA
    PROPERTY_HINT_MULITLINE
end

get_property_hint(element::Any, property::Symbol)::PropertyHint = PROPERTY_HINT_NONE

function modify_properties(element::T, handle::NodeHandle, flag::Int)::Tuple{Int, T} where T<:Any
    result::Int = EDIT_NODE_NONE
    properties::Dict{Symbol, Any} = Dict{Symbol, Any}()
    for f::Symbol in propertynames(element)
        old = getproperty(element, f)
        new = input_property(String(f)*"$handle", old, get_property_hint(element, f))
        if ismutable(element)
            setproperty!(element, f, new)
        else
            properties[f] = new
        end
        result |= flag * (old != new)
    end
    if !ismutable(element)
        element = reconstruct_node(element, properties)
    end
    return result, element
end

function input_property(label::String, value::T, property_hint::PropertyHint)::T where T
    if property_hint == PROPERTY_HINT_COLOR_ALPHA
        return color_edit4(label, value)
    elseif property_hint == PROPERTY_HINT_COLOR
        return color_edit3(label, value)
    elseif property_hint == PROPERTY_HINT_MULITLINE
        return input_multiline(label, value)
    else
        return input(label, value)
    end
end

function reconstruct_node(element::T, properties::Dict{Symbol, Any})::T where T <:Any return element end
rerender_node(render_data::Any, renderes::Dict{DataType, Renderer}, handle) = false
edit_node_overload(element::Any)::Bool = false
edit_node_type_string(element::Any)::String = string(typeof(element))


on_gizmo_select(element::Any,render_data::Any)::Tuple{UInt32,Vec3D,Any} = (AXIS_NONE, Vec3DNan, nothing) # Used gizmo axes, gizmo position, data
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

get_parent_node(parent::NodeHandle)::NodeHandle = parent
get_parent_nodes(parents::Any...)::Vector{NodeHandle} = [get_parent_node(parent) for parent in parents]
(handle::NodeHandle)(args::Any...) = get_element(handle)(handle, args...)

export update, convert_callback_entry, convert_callback_result, eval_node, render_node, render_node_gui, edit_node, edit_node_overload, reconstruct_node, rerender_node, get_property_hint
export on_gizmo_select, on_gizmo_move
export eval_geometry_node, GeometryPlotNode