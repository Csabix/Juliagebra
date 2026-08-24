struct TextBoxNode
    value::String

    TextBoxNode() = new("")
    TextBoxNode(text::String) = new(text)
end

convert_callback_entry(textbox::TextBoxNode)::String = textbox.value

convert_callback_result(::TextBoxNode, result) = TextBoxNode(String(result))
convert_callback_result(::TextBoxNode, ::Nothing) = TextBoxNode()

function render_node_gui(textbox::TextBoxNode)::Tuple{Any,Bool}
    CImGui.SetNextItemWidth(-1)
    proposed_text = txtbox("##textbox", textbox.value)

    invalidate = if isnothing(proposed_text)
        false
    else
        proposed_text != textbox.value
    end

    new_value = isnothing(proposed_text) ? textbox.value : proposed_text
    return TextBoxNode(new_value), invalidate
end

TextBox()::NodeHandle = add_node!(TextBoxNode())
TextBox(text::String)::NodeHandle=add_node!(TextBoxNode(text))
TextBox(callback::Function,parents::Union{Vector{NodeHandle},Nothing}=nothing)::NodeHandle=add_node!(callback,TextBoxNode();parents=parents)

macro TextBox(callback::Expr, args...)
    (positional_args, kw_args) = _parse_macro_arguments(tuple(), tuple(), args...)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.TextBox,
                                positional_args, kw_args)
end

export TextBox
export @TextBox