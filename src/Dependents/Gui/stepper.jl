
# ? ---------------------------------
# ! Stepper
# ? ---------------------------------

mutable struct StepperDependent <: GuiDependentDNA
    _dependent::GuiDependent
    _num::Float64

    function StepperDependent(callback::Function, dependents::Vector{<:DependentDNA}, label::String)
        dependent = GuiDependent(callback,dependents,label)
        new(dependent,0)
    end
end

_GuiDependent_(self::StepperDependent)::GuiDependent = return self._dependent

# YELLOW Thread
# RED Thread
onNodeEval(self::StepperDependent) = evalCallbackDp(self)

evalCallbackDpEntry(self::StepperDependent)::Float64 = return self._num

evalCallbackDpReturn(self::StepperDependent,num::Float64) = self._num = num

# ? ---------------------------------
# ! StepperRenderer
# ? ---------------------------------

@kwdef struct _StepperData
    playing::Bool = false
    opened::Bool = false
    proposed::Union{Float32,Nothing} = nothing
    start::Vec2D = Vec2D(0.0,0.0)
end

mutable struct StepperRenderer <: GuiRendererDNA{StepperDependent}
    _renderer::GuiRenderer{StepperDependent}
    _nums::Vector{Float64}
    _data::Vector{_StepperData}
    StepperRenderer(imgui::ImGuiDNA) = new(GuiRenderer{StepperDependent}(imgui),Vector{Float64}(),Vector{_StepperData}())
end

_GuiRenderer_(self::StepperRenderer)::GuiRenderer{StepperDependent} = return self._renderer

title(::StepperRenderer) = return "Stepper"
addedAll!(::StepperRenderer) = return nothing
syncAll!(::StepperRenderer) = return nothing

# GREEN Thread
function _added!(self::StepperRenderer, item::StepperDependent) 
    push!(self._nums, item._num)
    push!(self._data, _StepperData())
end

# GREEN Thread
function sync!(self::StepperRenderer, item::StepperDependent) 
    self._nums[getObserverID(item)] = item._num
end

function update!(self::StepperRenderer, app::AppDNA)
    m::Model = getModel(app)
    steppers::Vector{StepperDependent} = getObservedItems(self)

    for stepperIdx in eachindex(steppers)
        stepper::StepperDependent = steppers[stepperIdx]
        data::_StepperData = self._data[stepperIdx]

        if data.playing
            tt = time() - data.start.x
            stepper._num = data.start.y + tt
            schedule(m,stepper)

        elseif !isnothing(data.proposed)
            stepper._num = Float64(data.proposed)
            schedule(m,stepper)
        end
    end
end

function render!(self::StepperRenderer, stepper::StepperDependent, app::AppDNA)
    imgui::ImGuiData = getImGui(app)
    label::String = getLabel(stepper)
    stepperIdx::Int = getObserverID(stepper)
    num::Float32 = self._nums[stepperIdx]
    data::_StepperData = self._data[stepperIdx]

    playing = data.playing
    opened = data.opened
    #proposed = data.proposed
    #start = data.start

    playButtonChar= playing ? "\ue034" : "\ue037" 

    # ? Sizing here is good enough for now.
    CImGui.PushFont(imgui._iconFont, 21)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FramePadding, CImGui.ImVec2(0, 0))
    CImGui.Button("\ue8b8") ? opened = !opened : nothing # ? Settings Cog
    CImGui.SameLine(0.0,5.0)
    CImGui.Button(playButtonChar) ? playing = !playing : nothing # ? Play Button
    start = data.playing==false && playing==true ? Vec2D(time(),num) : data.start
    CImGui.PopStyleVar()
    CImGui.PopFont()

    if label==""
        CImGui.SameLine(0.0,5.0)
    else
        CImGui.SameLine(0.0,5.0)
        CImGui.Text("$(label)")
        CImGui.SameLine(0.0,5.0)
    end
    
    CImGui.SetNextItemWidth(-1)
    proposed = input1(num,"", Float32(0.1), Float32(1))

    if opened
        CImGui.Button("Implement Anim Styles!")
        CImGui.SameLine(0.0,5.0)
        CImGui.Button("Implement Anim Speed!")
        CImGui.SameLine(0.0,5.0)
        CImGui.Button("Implement Value Setting!")
        CImGui.Spacing()
    end

    self._data[stepperIdx] = _StepperData(playing, opened, proposed, start)
end

# ? ---------------------------------
# ! Stepper
# ? ---------------------------------

Stepper(num::Real; label="") =
Build!(StepperDependent(Vector{DependentDNA}(), label) do 
    return Float64(num) 
end)

Stepper(vh::ValueHolderDNA{<:Real}; label="") =
Build!(StepperDependent([vh], label) do vh
    return Float64(vh)
end)

export Stepper