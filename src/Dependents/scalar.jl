
edit_node_overload(scalar::Float64)::Bool = true
function edit_node(scalar::Float64,::Any,::Dict{DataType,Renderer},::NodeHandle)::Tuple{Any,Any,Int}
    CImGui.Text("$scalar")
    return (round(scalar;digits=4),nothing,EDIT_NODE_NONE)
end
