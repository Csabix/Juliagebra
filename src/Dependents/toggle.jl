
# ? ---------------------------------
# ! TogglePlan
# ? ---------------------------------

mutable struct TogglePlan <: GuiPlanDNA
    _plan::GuiPlan

    function TogglePlan(callback::Function,plans::Vector{T}) where {T<:PlanDNA}
        new(GuiPlan(callback,plans))
    end
end

_GuiPlan_(self::TogglePlan)::GuiPlan = return self._plan

# ? ---------------------------------
# ! ToggleDependent
# ? ---------------------------------

mutable struct ToggleDependent <: GuiDependentDNA
    _dependent::GuiDependent
    _toggled::Bool

    function ToggleDependent(plan::TogglePlan)
        dependent = GuiDependent(plan)
        toggled = false
        new(dependent,toggled)
    end
end

_GuiDependent_(self::ToggleDependent) = return self._dependent

isToggled(self::ToggleDependent) = return self._toggled
flip!(self::ToggleDependent) = self._toggled = !self._toggled

# TODO: Finish theese functions 
evalCallback(self::ToggleDependent,params...) = error("TODO - Finish this!")
dpCallbackReturn(self::ToggleDependent,::Nothing) = error("TODO - Finish this!")
onGraphEval(self::ToggleDependent) =  error("TODO - Finish this!")


# ? ---------------------------------
# ! ToggleRenderer
# ? ---------------------------------

mutable struct ToggleRenderer <: GuiRendererDNA{ToggleDependent}
    _guiRenderer::GuiRenderer{ToggleDependent}

    function ToggleRenderer()
        guiRenderer = GuiRenderer{ToggleDependent}()

        new(guiRenderer)
    end
end

_GuiRenderer_(self::ToggleRenderer) = return self._guiRenderer

added!(self::ToggleRenderer,item::ToggleDependent) = return nothing
sync!(self::ToggleRenderer,item::ToggleDependent) = return nothing
syncAll!(self::ToggleRenderer) = return nothing
addedAll!(self::ToggleRenderer) = return nothing

function render!(self::ToggleRenderer)
    for toggleIdx in eachindex(getObservedItems(self))
        toggle = self[toggleIdx]

        CImGui.Button("Toggle[$(toggleIdx)]")

    end
end

function Plan2Observer(self::ImGuiData,plan::TogglePlan)
    return SingleGuiRendererByGuiDependentsWindow(self,ToggleRenderer)
end

function Plan2Dependent(plan::TogglePlan)
    return ToggleDependent(plan)
end