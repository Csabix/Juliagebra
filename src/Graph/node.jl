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
    result_element, element = modify_properties(element, handle, EDIT_NODE_INVALIDATE)
    CImGui.Separator()
    CImGui.Text("Render Data")
    result_data, render_data = modify_properties(render_data, handle, EDIT_NODE_RERENDER)
    result::Int = result_element | result_data
    if result & EDIT_NODE_RERENDER != 0
        rerender_node(render_data, renderers)
    end
    return element, render_data, result
end



abstract type PropertyHint end

struct PropertyHintSlider <: PropertyHint
    min::Real
    max::Real
    function PropertyHintSlider(min::Real = 0f, max::Real = 1f)
        new(min, max)
    end
end

struct PropertyHintColor <: PropertyHint
    input_alpha::Bool
    function PropertyHintColor(input_alpha::Bool = false)
        new(input_alpha)
    end
end

struct PropertyHintNumber <: PropertyHint
    step::Real
    step_fast::Real
    function PropertyHintNumber(step::Real=1f, step_fast::Real=5f)
        new(step, step_fast)
    end
end


struct PropertyHintText <: PropertyHint
    buffer_size::Int
    function PropertyHintText(buffer_size::Int=1024)
        new(buffer_size)
    end
end

struct PropertyHintTextMultiline <: PropertyHint
    buffer_size::Int
    textbox_size::Vec2F
    function PropertyHintTextMultiline(buffer_size::Int=1024, textbox_size::CImGui.ImVec2 = CImGui.ImVec2(CImGui.GetContentRegionAvail().x,100))
        new(buffer_size, textbox_size)
    end
end

get_property_hint(element::Any, property::Symbol)::Union{PropertyHint, Nothing} = nothing

function modify_properties(element::T, handle::NodeHandle, flag::Int)::Tuple{Int, T} where T<:Any
    result::Int = EDIT_NODE_NONE
    properties::Dict{Symbol, Any} = Dict{Symbol, Any}()
    for f::Symbol in propertynames(element)
        old = getproperty(element, f)
        new = input_property(String(f), old, get_property_hint(element, f))
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

function input_property(label::String, value::T, property_hint::Union{PropertyHint, Nothing} = nothing)::T where T
    if value isa Vector
        rt::Vector = []
        for v in eachindex(value)
            push!(rt, input_property(label*"$v", value[v], property_hint))
        end
        return rt
    end
    if property_hint isa PropertyHintColor
        if (property_hint::PropertyHintColor).input_alpha
            return color_edit4(label, value)
        else
            return color_edit3(label, value)
        end
    elseif property_hint isa PropertyHintSlider
        ps::PropertyHintSlider = property_hint::PropertyHintSlider
        return slider(label, value, ps.min, ps.max)
    elseif property_hint isa PropertyHintNumber
        pn::PropertyHintNumber = property_hint
        return input(label, value, pn.step, pn.step_fast)
    elseif property_hint isa PropertyHintText
        pt::PropertyHintText = property_hint
        return input(label, value, pt.buffer_size)
    elseif property_hint isa PropertyHintTextMultiline
        pm::PropertyHintTextMultiline = property_hint
        return input_multiline(label, value, pm.buffer_size, pm.textbox_size)
    else
        return input(label, value)
    end
end

function reconstruct_node(element::T, properties::Dict{Symbol, Any})::T where T <:Any return element end
rerender_node(render_data::Any, renderes::Dict{DataType, Renderer}) = false
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

export update, convert_callback_entry, convert_callback_result, eval_node, render_node, render_node_gui, edit_node, edit_node_overload, reconstruct_node, rerender_node, get_property_hint, property_hint_params
export on_gizmo_select, on_gizmo_move
export eval_geometry_node, GeometryPlotNode