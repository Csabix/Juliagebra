struct Slider
    value::Float64
    min_value::Float64
    max_value::Float64
    start_value::Float64
    label::Union{String,Nothing}
    playing::Bool

    Slider(value::Float64,min_value::Float64,max_value::Float64,label::Union{String,Nothing}) = new(value,min_value,max_value,value,label,false)
    Slider(s::Slider,value::Float64) = new(value,s.min_value,s.max_value,s.start_value,s.label,s.playing)
    Slider(s::Slider,value::Float64,playing::Bool) = new(value,s.min_value,s.max_value,s.start_value,s.label,playing)
end

convert_callback_entry(slider::Slider)::Float64 = slider.value

convert_callback_result(slider::Slider, result) = Slider(slider,clamp(Float64(result),slider.min_value,slider.max_value))

function update(slider::Slider,delta_time::Float64)::Tuple{Any,Bool}
    if slider.playing
        value::Float64 = slider.value + delta_time
        if value > slider.max_value
            if slider.min_value != -Inf64
                slider_range::Float64 = slider.max_value - slider.min_value
                value = value - floor(value / slider_range) * slider_range
            else
                value = slider.start_value
            end
        end
        return Slider(slider,value), true
    else
        return slider, false
    end
end

function render_node_gui(slider::Slider)::Any
    global implicitApp
    app::App = implicitApp
    imgui::ImGuiData = getImGui(app)

    playing = slider.playing
    playButtonChar= playing ? "\ue034" : "\ue037"

    CImGui.PushFont(imgui._iconFont, 21)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FramePadding, CImGui.ImVec2(0, 0))
    CImGui.Button(playButtonChar) ? playing = !playing : nothing
    CImGui.PopStyleVar()
    CImGui.PopFont()

    if (slider.label === nothing)
        CImGui.SameLine(0.0,5.0)
    else
        CImGui.SameLine(0.0,5.0)
        CImGui.Text(slider.label)
        CImGui.SameLine(0.0,5.0)
    end

    CImGui.SetNextItemWidth(-1)
    value::Float64 = slider1(slider.value,"",slider.min_value,slider.max_value)
    invalidate = slider.value != value
    return Slider(slider,value,playing), invalidate
end

Slider(; label::Union{String,Nothing}=nothing)::NodeHandle = add_node!(Slider(0.5,0.0,1.0,label))
function Slider(maxVal::Real; label::Union{String,Nothing}=nothing)::NodeHandle
    @assert maxVal > 0.0
    add_node!(Slider(Float64(maxVal)/2.0,0.0,Float64(maxVal),label))
end
function Slider(minVal::Real, maxVal::Real; label::Union{String,Nothing}=nothing)::NodeHandle
    @assert maxVal > minVal
    add_node!(Slider((Float64(maxVal) - Float64(minVal))/2.0,Float64(minVal),Float64(maxVal),label))
end
function Slider(minVal::Real, currVal::Real, maxVal::Real; label::Union{String,Nothing}=nothing)::NodeHandle
    @assert maxVal > minVal && maxVal >= currVal >= minVal
    add_node!(Slider(Float64(currVal),Float64(minVal),Float64(maxVal),label))
end

#Slider(callback::Function,dependents::Vector{<:DependentDNA}; label="") =
#Build!(SliderDependent(callback,dependents,label))

macro Slider(callback::Expr, args...)
    (positional_args, kw_args) = _parse_macro_arguments(tuple(),(:label,), args...)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.Slider,
                                positional_args, kw_args)
end

export Slider
export @Slider