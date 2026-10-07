struct ToggleNode
    value::Bool
    label::String

    ToggleNode() = new(false, "")
    ToggleNode(value::Bool, label::String="") = new(value, label)
end

convert_callback_entry(toggle::ToggleNode)::Bool = toggle.value

function render_node_gui(toggle::ToggleNode)::Tuple{Any,Bool}
    value_ref = Ref(toggle.value)
    CImGui.Checkbox(isempty(toggle.label) ? "##toggle" : toggle.label, value_ref)
    invalidate = value_ref[] != toggle.value
    return ToggleNode(value_ref[], toggle.label), invalidate
end

Toggle(; label::String="")::NodeHandle = add_node!(ToggleNode(false, label))
Toggle(value::Bool; label::String="")::NodeHandle = add_node!(ToggleNode(value, label))

export Toggle
