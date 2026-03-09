
# ? ---------------------------------
# ! ToggleDependent
# ? ---------------------------------

mutable struct ToggleDependent <: GuiDependentDNA
    _dependent::GuiDependent
    _state::Bool

    # BLUE Thread
    function ToggleDependent(callback::Function,dependents::Vector{<:DependentDNA})
        dependent = GuiDependent(callback,dependents)
        toggled = false

        new(dependent,toggled)
    end
end

_GuiDependent_(self::ToggleDependent) = return self._dependent


_flip!(self::ToggleDependent) = self._state = !self._state


# BLUE Thread
# RED Thread
onNodeEval(self::ToggleDependent) = evalCallbackDp(self)

evalCallbackDpEntry(self::ToggleDependent)::Bool = return self._state

evalCallbackDpReturn(self::ToggleDependent, val::Bool) = self._state = val
evalCallbackDpReturn(self::ToggleDependent, ::Nothing) = return nothing

# ? ---------------------------------
# ! ToggleRenderer
# ? ---------------------------------

mutable struct ToggleRenderer <: GuiRendererDNA{ToggleDependent}
    _guiRenderer::GuiRenderer{ToggleDependent}

    # GREEN Thread
    function ToggleRenderer()
        guiRenderer = GuiRenderer{ToggleDependent}()

        new(guiRenderer)
    end
end

_GuiRenderer_(self::ToggleRenderer) = return self._guiRenderer

# GREEN Thread
added!(::ToggleRenderer,::ToggleDependent) = return nothing

# GREEN Thread
addedAll!(::ToggleRenderer) = return nothing

# GREEN Thread
sync!(::ToggleRenderer,::ToggleDependent) = return nothing

# GREEN Thread
syncAll!(::ToggleRenderer) = return nothing

# GREEN Thread
function render!(self::ToggleRenderer)
    CImGui.Text("ToggleDependents:")
    CImGui.Separator()

    for toggleIdx in eachindex(getObservedItems(self))
        toggle::ToggleDependent = self[toggleIdx]

        toggleState = toggle._state
        toggleStateRef = Ref(toggleState)

        if(CImGui.Checkbox("Toggle[$(toggleIdx)]",toggleStateRef))
            # ! Take into note, that the user can only click on one element at every frame,
            # ! so multiple evalGraph calls under a single frame can't happen!
            _flip!(toggle)
            evalGraph(toggle)
        end

    end
end

# BLUE Thread
Dependent2ObserverT(::ToggleDependent) = ToggleRenderer

# ? ---------------------------------
# ! Toggle
# ? ---------------------------------

# YELLOW Thread
Toggle() =
build!(() -> ToggleDependent(() -> (return false), Vector{DependentDNA}()))

# YELLOW Thread
Toggle(callback::Function,dependents::Vector{<:DependentDNA}) =
build!(() -> ToggleDependent(callback, dependents))

export Toggle