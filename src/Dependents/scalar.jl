
struct ScalarData
    label::String
end

render_node(::Real,data::Any,::Dict{DataType,Renderer},::UInt32)::Any = data

edit_node_overload(scalar::Real)::Bool = true
function edit_node(scalar::Real,data::ScalarData,::Dict{DataType,Renderer},::NodeHandle)::Tuple{Any,Any,Int}
    text = "$(data.label)"
    if (length(data.label) > 0)
        text *= ": "
    end
    text *= "$(round(scalar;digits=4))"
    
    CImGui.Text(text)
    return (scalar,data,EDIT_NODE_NONE)
end

# ? ---------------------------------
# ! Scalar constructors
# ? ---------------------------------

_get_scalar_draw_data(label::Union{String,Nothing}) = label !== nothing ? ScalarData(label) : ScalarData("")

function Scalar end

function Scalar(callback::Function,parents::Union{Vector{NodeHandle},Nothing}=nothing;label::Union{String,Nothing}=nothing)::NodeHandle
    return add_node!(callback; parents=parents,draw_data=_get_scalar_draw_data(label))
end

function Scalar(n::Real;label::Union{String,Nothing}=nothing)
    return add_node!(n; draw_data=_get_scalar_draw_data(label))
end

export Scalar
