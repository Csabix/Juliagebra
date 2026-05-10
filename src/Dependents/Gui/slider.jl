
# ? ---------------------------------
# ! SliderDependent
# ? ---------------------------------

mutable struct SliderDependent <: GuiDependentDNA
    _dependent::GuiDependent
    _value::Vec3F # ? x is minVal, y is currVal, z is maxVal

    # YELLOW Thread
    function SliderDependent(callback::Function, dependents::Vector{<:DependentDNA},label::String)
        dependent = GuiDependent(callback,dependents,label)
        value = Vec3FNan

        new(dependent,value)
    end
end

_GuiDependent_(self::SliderDependent)::GuiDependent = return self._dependent

# YELLOW Thread
# RED Thread
onNodeEval(self::SliderDependent) = evalCallbackDp(self)

Base.eltype(dependent::SliderDependent)::DataType = Float64

evalCallbackDpEntry(self::SliderDependent)::Float64 = return Float64(self._value.y)

evalCallbackDpReturn(self::SliderDependent, v::Vec3F) = self._value = v

# ? ---------------------------------
# ! SliderRenderer
# ? ---------------------------------

@kwdef struct _SliderData
    playing::Bool = false
    opened::Bool = false
    proposed::Union{Float32,Nothing} = nothing
    start::Float64 = 0.0
end

mutable struct SliderRenderer <: GuiRendererDNA{SliderDependent}
    _guiRenderer::GuiRenderer{SliderDependent}
    _values::Vector{Vec3F}
    _data::Vector{_SliderData}
    SliderRenderer(imgui::ImGuiDNA) = new(GuiRenderer{SliderDependent}(imgui),Vector{Vec3F}(),Vector{_SliderData}())
end

_GuiRenderer_(self::SliderRenderer) = return self._guiRenderer

syncAll!(self::SliderRenderer) = return nothing
addedAll!(self::SliderRenderer) = return nothing
title(::SliderRenderer)::String = return "Slider"

# GREEN Thread
function _added!(self::SliderRenderer,item::SliderDependent) 
    push!(self._values, item._value)
    push!(self._data, _SliderData())
end

# GREEN Thread
function sync!(self::SliderRenderer,item::SliderDependent)
    self._values[getObserverID(item)] = item._value
end

const ANIM_LENGTH = 5.0

function update!(self::SliderRenderer, app::AppDNA)
    sliders::Vector{SliderDependent} = getSubjectItems(self)
    m::Model = getModel(app)

    for sliderIdx in  eachindex(sliders)
        slider::SliderDependent = sliders[sliderIdx]
        value::Vec3F = self._values[sliderIdx]
        data::_SliderData = self._data[sliderIdx]
        
        if data.playing
            minVal = value.x
            maxVal = value.z
            
            t=mod(time()-data.start, ANIM_LENGTH)
            tt=0.0

            if t<(ANIM_LENGTH/2.0)
                tt = t/(ANIM_LENGTH/2.0)
            else
                tt = 1.0-((t-(ANIM_LENGTH/2.0))/(ANIM_LENGTH/2.0))
            end

            slider._value = Vec3F(minVal,minVal*(1-tt)+tt*maxVal,maxVal)
            schedule(m,slider)
        elseif !isnothing(data.proposed)            
            slider._value = Vec3F(value.x,data.proposed,value.z)
            schedule(m,slider)
        end
    end
end

function render!(self::SliderRenderer, slider::SliderDependent, app::AppDNA)
    imgui::ImGuiData = getImGui(app)
    label::String = getLabel(slider)
    value::Vec3F = self._values[getObserverID(slider)]
    data::_SliderData = self._data[getObserverID(slider)]

    minVal = value.x
    currVal = value.y
    maxVal = value.z

    playing = data.playing
    opened = data.opened

    playButtonChar= playing ? "\ue034" : "\ue037" 

    # ? Sizing here is good enough for now.
    CImGui.PushFont(imgui._iconFont, 21)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FramePadding, CImGui.ImVec2(0, 0))
    CImGui.Button("\ue8b8") ? opened = !opened : nothing # ? Settings Cog
    CImGui.SameLine(0.0,5.0)
    CImGui.Button(playButtonChar) ? playing = !playing : nothing # ? Play Button
    start = data.playing==false && playing==true ? time() : data.start
    CImGui.PopStyleVar()
    CImGui.PopFont()

    if (label == "")
        CImGui.SameLine(0.0,5.0)
    else
        CImGui.SameLine(0.0,5.0)
        CImGui.Text("$(label)")
        CImGui.SameLine(0.0,5.0)
    end

    CImGui.SetNextItemWidth(-1)
    proposed = slider1(currVal,"",minVal,maxVal)

    if opened
        CImGui.Button("Implement Anim Styles!")
        CImGui.SameLine(0.0,5.0)
        CImGui.Button("Implement Anim Speed!")
        CImGui.SameLine(0.0,5.0)
        CImGui.Button("Implement Value Setting!")
        CImGui.Spacing()
    end

    self._data[getObserverID(slider)] = _SliderData(playing,opened,proposed,start)
end

# ? ---------------------------------
# ! Slider
# ? ---------------------------------

# YELLOW Thread
Slider(; label="") =
Build!(SliderDependent(Vector{DependentDNA}(),label) do 
    return Vec3F(0.0,0.5,1.0)    
end)

# YELLOW Thread
Slider(maxVal::Real; label="") =
Build!(SliderDependent(Vector{DependentDNA}(),label) do 
    return Vec3F(0.0,maxVal/2.0,abs(maxVal))    
end)

# YELLOW Thread
Slider(minVal::Real, maxVal::Real; label="") =
Build!(SliderDependent(Vector{DependentDNA}(),label) do 
    return Vec3F(minVal,((maxVal-minVal)/2.0)+minVal,maxVal)    
end)

# YELLOW Thread
Slider(minVal::Real, currVal::Real, maxVal::Real; label="") =
Build!(SliderDependent(Vector{DependentDNA}(),label) do 
    return Vec3F(minVal,currVal,maxVal)    
end)

# YELLOW Thread
Slider(callback::Function,dependents::Vector{<:DependentDNA}; label="") =
Build!(SliderDependent(callback,dependents,label))

macro Slider(callback::Expr, kw_args...)
    parsed_kw_args = _parse_macro_kw_args([:label], kw_args...)
    _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.Slider; parsed_kw_args...)
end

export Slider
export @Slider