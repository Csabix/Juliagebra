
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
        toggle = new(dependent,toggled)

        onGraphEval(toggle)

        return toggle
    end
end

_GuiDependent_(self::ToggleDependent) = return self._dependent

isToggled(self::ToggleDependent) = return self._toggled
flip!(self::ToggleDependent) = self._toggled = !self._toggled

export isToggled
 
evalCallback(self::ToggleDependent) = getCallback(self)(getGraphParents(self)...)
dpCallbackReturn(self::ToggleDependent, val::Bool) = self._toggled = val
dpCallbackReturn(self::ToggleDependent, ::Nothing) = return nothing

function onGraphEval(self::ToggleDependent)
    dpEvalCallback(self)
end


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

        toggleVal = isToggled(toggle)
        toggleValRef = Ref(toggleVal)

        if(CImGui.Checkbox("Toggle[$(toggleIdx)]",toggleValRef))
            flip!(toggle)
            evalGraph(toggle)
        end

    end
end

function Plan2Observer(self::ImGuiData,plan::TogglePlan)
    return SingleGuiRendererByGuiDependentsWindow(self,ToggleRenderer)
end

function Plan2Dependent(plan::TogglePlan)
    return ToggleDependent(plan)
end