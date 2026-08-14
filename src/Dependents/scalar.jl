
edit_node_overload(scalar::Float64)::Bool = true
function edit_node(scalar::Float64,renderers::Dict{DataType,Renderer},handle::NodeHandle)::Tuple{Any,Bool}
    CImGui.Text("$scalar")
    return (round(scalar;digits=4),false)
end
