struct Stepper
    value::Float64
    start_value::Float64
    label::Union{String,Nothing}
    playing::Bool

    Stepper(value::Float64, label::Union{String,Nothing}) = new(value, value, label, false)
    Stepper(s::Stepper, value::Float64) = new(value, s.start_value, s.label, s.playing)
    Stepper(s::Stepper, value::Float64, playing::Bool) = new(value, s.start_value, s.label, playing)
end

convert_callback_entry(stepper::Stepper)::Float64 = stepper.value

convert_callback_result(stepper::Stepper, result) = Stepper(stepper, Float64(result))

function update(stepper::Stepper, delta_time::Float64)::Tuple{Any,Bool}
    if stepper.playing
        value::Float64 = stepper.value + delta_time
        return Stepper(stepper, value), true
    else
        return stepper, false
    end
end

function render_node_gui(stepper::Stepper)::Any
    global implicitApp
    app::App = implicitApp
    imgui::ImGuiData = getImGui(app)
    invalidate = false

    playing = stepper.playing
    playButtonChar = playing ? "\ue034" : "\ue037"

    CImGui.PushFont(imgui._iconFont, 21)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FramePadding, CImGui.ImVec2(0, 0))
    CImGui.Button("\ue8b8") ? nothing : nothing # Settings Cog (placeholder)
    CImGui.SameLine(0.0, 5.0)
    if CImGui.Button(playButtonChar)
        playing = !playing
        invalidate = true
    end
    CImGui.PopStyleVar()
    CImGui.PopFont()

    if (stepper.label === nothing)
        CImGui.SameLine(0.0, 5.0)
    else
        CImGui.SameLine(0.0, 5.0)
        CImGui.Text(stepper.label)
        CImGui.SameLine(0.0, 5.0)
    end

    CImGui.SetNextItemWidth(-1)
    value = input1(Float32(stepper.value), "", Float32(0.1), Float32(1))
    if value === nothing
        return Stepper(stepper, stepper.value, playing), invalidate
    end
    value_f::Float32 = value::Float32
    invalidate |= Float32(stepper.value) != value_f
    return Stepper(stepper, Float64(value_f), playing), invalidate
end

Stepper(; label::Union{String,Nothing}=nothing)::NodeHandle = add_node!(Stepper(0.0, label))
function Stepper(startVal::Real; label::Union{String,Nothing}=nothing)::NodeHandle
    add_node!(Stepper(Float64(startVal), label))
end

macro Stepper(callback::Expr, args...)
    (positional_args, kw_args) = _parse_macro_arguments(tuple(), (:label,), args...)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.Stepper,
                                positional_args, kw_args)
end

export Stepper
export @Stepper
