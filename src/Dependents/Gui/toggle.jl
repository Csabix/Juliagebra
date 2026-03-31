
# ? ---------------------------------
# ! ToggleDependent
# ? ---------------------------------

mutable struct ToggleDependent <: GuiDependentDNA
    _dependent::GuiDependent
    _state::Bool

    # YELLOW Thread
    function ToggleDependent(callback::Function,dependents::Vector{<:DependentDNA},label::String)
        dependent = GuiDependent(callback,dependents,label)
        toggled = false

        new(dependent,toggled)
    end
end

_GuiDependent_(self::ToggleDependent) = return self._dependent


_flip!(self::ToggleDependent) = self._state = !self._state


# YELLOW Thread
# RED Thread
onNodeEval(self::ToggleDependent) = evalCallbackDp(self)

evalCallbackDpEntry(self::ToggleDependent)::Bool = return self._state

evalCallbackDpReturn(self::ToggleDependent, val::Bool) = self._state = val
evalCallbackDpReturn(self::ToggleDependent, ::Nothing) = return nothing

# ? ---------------------------------
# ! ToggleRenderer
# ? ---------------------------------

# TODO: copy Bools, instead of views!
mutable struct ToggleRenderer <: GuiRendererDNA{ToggleDependent}
    _guiRenderer::GuiRenderer{ToggleDependent}

    # GREEN Thread
    ToggleRenderer(imgui::ImGuiDNA) = new(GuiRenderer{ToggleDependent}(imgui))
end

_GuiRenderer_(self::ToggleRenderer) = return self._guiRenderer

# GREEN Thread
_added!(::ToggleRenderer,::ToggleDependent) = return nothing

# GREEN Thread
addedAll!(::ToggleRenderer) = return nothing

# GREEN Thread
sync!(::ToggleRenderer,::ToggleDependent) = return nothing

# GREEN Thread
syncAll!(::ToggleRenderer) = return nothing

# GREEN Thread
function render!(self::ToggleRenderer, app::AppDNA)
    CImGui.Text("ToggleDependents:")
    CImGui.Separator()

    for toggleIdx in eachindex(getObservedItems(self))
        toggle::ToggleDependent = self[toggleIdx]
        render!(self,toggle,app)
    end
end

function render!(self::ToggleRenderer, toggle::ToggleDependent, app::AppDNA)
    s::Scheduler = getScheduler(app)
    label::String = getLabel(toggle)
    toggleIdx::Int = getObserverID(toggle)

    toggleState = toggle._state
    toggleStateRef = Ref(toggleState)

    if (CImGui.Checkbox("$(label)##$(toggleIdx)",toggleStateRef))
        _flip!(toggle)
        schedule(s,toggle)
    end
end

# ? ---------------------------------
# ! Toggle
# ? ---------------------------------

# YELLOW Thread
Toggle(; label="") =
build!(ToggleDependent(() -> (return false), Vector{DependentDNA}(),label))

# YELLOW Thread
Toggle(callback::Function,dependents::Vector{<:DependentDNA}; label="") =
build!(ToggleDependent(callback, dependents,label))

# YELLOW Thread
macro Toggle(callback::Expr, kw_args...)
    parsed_kw_args = _parse_macro_kw_args([:label], kw_args...)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.Toggle; parsed_kw_args...)
end


export Toggle
export @Toggle