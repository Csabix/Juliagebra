
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

Base.eltype(dependent::ToggleDependent)::DataType = Bool

evalCallbackDpEntry(self::ToggleDependent)::Bool = return self._state

evalCallbackDpReturn(self::ToggleDependent, val::Bool) = self._state = val
evalCallbackDpReturn(self::ToggleDependent, ::Nothing) = return nothing

get_glsl_representation(::Type{ToggleDependent}) = Bool
function try_upload_dependent(uniform::GLint, t::ToggleDependent)::Bool
    glUniform1i(uniform, GLint(t._state))
    return true
end

# ? ---------------------------------
# ! ToggleRenderer
# ? ---------------------------------

mutable struct ToggleRenderer <: GuiRendererDNA{ToggleDependent}
    _renderer::GuiRenderer{ToggleDependent}
    _values::Vector{Bool}
    _clicked::Set{Int}
    ToggleRenderer(imgui::ImGuiDNA) = new(GuiRenderer{ToggleDependent}(imgui),Vector{Bool}(),Set{Int}())
end

_GuiRenderer_(self::ToggleRenderer) = return self._renderer

title(::ToggleRenderer)::String = return "Toggle"
addedAll!(::ToggleRenderer) = return nothing
syncAll!(::ToggleRenderer) = return nothing

# GREEN Thread
function _added!(self::ToggleRenderer,toggle::ToggleDependent)
    push!(self._values,toggle._state)
end

# GREEN Thread
function sync!(self::ToggleRenderer,toggle::ToggleDependent)
    self._values[getObserverID(toggle)] = toggle._state
end

function update!(self::ToggleRenderer, app::AppDNA)
    m::Model = getModel(app)
    s::Scheduler = getScheduler(m)

    for idx in self._clicked  
        toggle::ToggleDependent = getSubjectItems(self)[idx]
        _flip!(toggle)
        schedule(s,toggle)
    end

    empty!(self._clicked)
end

function render!(self::ToggleRenderer, toggle::ToggleDependent, app::AppDNA)
    label::String = getLabel(toggle)
    toggleIdx::Int = getObserverID(toggle)
    value = self._values[toggleIdx]

    valueRef = Ref(value)
    if (CImGui.Checkbox("$(label)##$(toggleIdx)",valueRef))
        push!(self._clicked,toggleIdx)
    end
end

# ? ---------------------------------
# ! Toggle
# ? ---------------------------------

# YELLOW Thread
Toggle(; label="") =
Build!(ToggleDependent(() -> (return false), Vector{DependentDNA}(),label))

# YELLOW Thread
Toggle(callback::Function,dependents::Vector{<:DependentDNA}; label="") =
Build!(ToggleDependent(callback, dependents,label))

# YELLOW Thread
macro Toggle(callback::Expr, args...)
    (positional_args, kw_args) = _parse_macro_arguments(tuple(),(:label,), args...)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.Toggle,
                                positional_args, kw_args)
end


export Toggle
export @Toggle