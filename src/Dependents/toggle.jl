
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
        onNodeEval(toggle)
        return toggle
    end
end

_GuiDependent_(self::ToggleDependent) = return self._dependent

isToggled(self::ToggleDependent) = return self._toggled
getToggleField(self::ToggleDependent,fieldVal::Val{:state}) = return self._toggled
Base.getindex(self::ToggleDependent,fieldSymbol::Symbol) = return getToggleField(self,Val(fieldSymbol))

flip!(self::ToggleDependent) = self._toggled = !self._toggled

onNodeEval(self::ToggleDependent) = evalCallbackDp(self)
evalCallbackDpReturn(self::ToggleDependent, val::Bool) = self._toggled = val
evalCallbackDpReturn(self::ToggleDependent, ::Nothing) = return nothing



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
    CImGui.Text("ToggleDependents:")
    CImGui.Separator()

    for toggleIdx in eachindex(getObservedItems(self))
        toggle = self[toggleIdx]

        toggleVal = toggle[:state]
        toggleValRef = Ref(toggleVal)

        if(CImGui.Checkbox("Toggle[$(toggleIdx)]",toggleValRef))
            # ! Take into note, that the user can only click on one element at every frame,
            # ! so multiple evalGraph calls under a single frame can't happen!
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