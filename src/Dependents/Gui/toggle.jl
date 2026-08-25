struct ToggleNode
    value::Bool

    ToggleNode() = new(false)
    ToggleNode(value::Bool) = new(value)
end

convert_callback_entry(toggle::ToggleNode)::Bool = toggle.value

function render_node_gui(toggle::ToggleNode)::Tuple{Any,Bool}
    value_ref = Ref(toggle.value)
    CImGui.Checkbox("##toggle", value_ref)
    invalidate = value_ref[] != toggle.value
    return ToggleNode(value_ref[]), invalidate
end

Toggle()::NodeHandle = add_node!(ToggleNode())
Toggle(value::Bool)::NodeHandle = add_node!(ToggleNode(value))

export Toggle