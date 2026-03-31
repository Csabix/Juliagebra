
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

mutable struct StepperRenderer <: GuiRendererDNA{StepperDependent}
    _renderer::GuiRenderer{StepperDependent}
    _nums::Vector{Float64}
    StepperRenderer(imgui::ImGuiDNA) = new(GuiRenderer{StepperDependent}(imgui),Vector{Float64}())
end

_GuiRenderer_(self::StepperRenderer)::GuiRenderer{StepperDependent} = return self._renderer

_added!(self::StepperRenderer, item::StepperDependent) = push!(self._nums,item._num)

# GREEN Thread
addedAll!(::StepperRenderer) = return nothing

# GREEN Thread
sync!(self::StepperRenderer, item::StepperDependent) = self._nums[getObserverID(item)] = item._num

# GREEN Thread
syncAll!(::StepperRenderer) = return nothing

function render!(self::StepperRenderer, app::AppDNA)
    
    CImGui.Text("Steppers:")
    CImGui.Separator()

    for stepperIdx in eachindex(getObservedItems(self))
        stepper::StepperDependent = getObservedItems(self)[stepperIdx]
        render!(self,stepper,app)
    end
end

function render!(self::StepperRenderer, stepper::StepperDependent, app::AppDNA)
    s::Scheduler = getScheduler(app)
    label::String = getLabel(stepper)
    stepperIdx::Int = getObserverID(stepper)
    num::Float32 = self._nums[stepperIdx]

    proposedVal = input1(num,"$(label)##$(stepperIdx)", Float32(0.1), Float32(1))

    if !isnothing(proposedVal)
        stepper._num = Float64(proposedVal)
        schedule(s,stepper)
    end
end

# ? ---------------------------------
# ! Stepper
# ? ---------------------------------

Stepper(num::Real; label="") =
build!(StepperDependent(Vector{DependentDNA}(), label) do 
    return Float64(num) 
end)

Stepper(vh::ValueHolderDNA{<:Real}; label="") =
build!(StepperDependent([vh], label) do vh
    return Float64(vh)
end)

export Stepper