
edit_node_overload(scalar::Float64)::Bool = true
function edit_node(scalar::Float64,::Any,::Dict{DataType,Renderer},::NodeHandle)::Tuple{Any,Any,Int}
    CImGui.Text("$(round(scalar;digits=4))")
    return (scalar,nothing,EDIT_NODE_NONE)
end
