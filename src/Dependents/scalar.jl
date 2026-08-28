
struct ScalarData
    label::String

    function ScalarData(label::Union{String,Nothing})
        new(label !== nothing ? label : "")
    end
end

edit_node_overload(scalar::Real)::Bool = true
edit_node_name(::Real) = "Scalar"
function edit_node(scalar::Real,data::ScalarData,::Dict{DataType,Renderer},::NodeHandle)::Tuple{Any,Any,Int}
    text = "$(data.label)"
    if (length(data.label) > 0)
        text *= ": "
    end
    text *= isa(scalar, Integer) ? string(scalar) : "$(round(scalar;digits=4))"
    
    CImGui.Text(text)
    return (scalar,data,EDIT_NODE_NONE)
end

# ? ---------------------------------
# ! Scalar constructors
# ? ---------------------------------

get_parent_node(parent::Real)::NodeHandle = add_node!(parent)

function Scalar end

function Scalar(callback::Function,parents::Union{Vector{NodeHandle},Nothing}=nothing;label::Union{String,Nothing}=nothing)::NodeHandle
    return add_node!(callback; parents=parents,draw_data=ScalarData(label))
end

function Scalar(n::Real;label::Union{String,Nothing}=nothing)
    return add_node!(n; draw_data=ScalarData(label))
end

export Scalar
