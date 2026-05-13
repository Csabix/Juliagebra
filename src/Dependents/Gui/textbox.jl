
# ? ---------------------------------
# ! TextBoxDependent
# ? ---------------------------------

mutable struct TextBoxDependent <: GuiDependentDNA
    _dependent::GuiDependent
    _text::String

    # YELLOW Thread
    function TextBoxDependent(callback::Function, dependents::Vector{<:DependentDNA},label::String)
        dependent = GuiDependent(callback,dependents,label)
        text = ""

        new(dependent,text)
    end
end

_GuiDependent_(self::TextBoxDependent)::GuiDependent = return self._dependent

# YELLOW Thread
# RED Thread
onNodeEval(self::TextBoxDependent) = evalCallbackDp(self)

Base.eltype(dependent::TextBoxDependent)::DataType = String

evalCallbackDpEntry(self::TextBoxDependent)::String = return self._text   

evalCallbackDpReturn(self::TextBoxDependent, text::String) = self._text = text

# ? ---------------------------------
# ! TextBoxRenderer
# ? ---------------------------------

mutable struct TextBoxRenderer <: GuiRendererDNA{TextBoxDependent}
    _renderer::GuiRenderer{TextBoxDependent}
    _data::Vector{String}
    _applied::Set{Int}
    TextBoxRenderer(imgui::ImGuiDNA) = new(GuiRenderer{TextBoxDependent}(imgui),Vector{String}(),Set{Int}())
end

_GuiRenderer_(self::TextBoxRenderer) = return self._renderer

syncAll!(self::TextBoxRenderer) = return nothing
addedAll!(self::TextBoxRenderer) = return nothing
title(::TextBoxRenderer)::String = return "TextBox"

# GREEN Thread
function _added!(self::TextBoxRenderer,item::TextBoxDependent)
    push!(self._data, item._text)
end

# GREEN Thread
function sync!(self::TextBoxRenderer,item::TextBoxDependent)
    self._data[getObserverID(item)] = item._text
end

function update!(self::TextBoxRenderer, app::AppDNA)
    m::ModelDNA = getModel(app)
    s::Scheduler = getScheduler(m)

    for idx in self._applied 
        textBox::TextBoxDependent = getSubjectItems(self)[idx]
        textBox._text = self._data[idx]
        schedule(s,textBox)
    end

    empty!(self._applied)
end

function render!(self::TextBoxRenderer, textBox::TextBoxDependent, app::AppDNA)
    label::String = getLabel(textBox)
    textBoxIdx::Int = getObserverID(textBox)
    data = self._data[textBoxIdx]

    if !(label == "")
        CImGui.Text("$(label)")
    end

    proposedText = txtbox("##$(textBoxIdx)",data)
    self._data[textBoxIdx] = isnothing(proposedText) ? data : proposedText 

    if (CImGui.Button("Apply $(label)##$(textBoxIdx)"))
        push!(self._applied,textBoxIdx)
    end
end

# ? ---------------------------------
# ! TextBox
# ? ---------------------------------

# YELLOW Thread
TextBox(; label="") =
Build!(TextBoxDependent(Vector{DependentDNA}(),label) do 
    return ""
end)

# YELLOW Thread
TextBox(text::String; label="") =
Build!(TextBoxDependent(Vector{DependentDNA}(),label) do 
    return text
end)

# YELLOW Thread
TextBox(callback::Function, dependents::Vector{<:DependentDNA}; label="") =
Build!(TextBoxDependent(callback,dependents,label))

# YELLOW Thread
macro TextBox(callback::Expr, args...)
    (positional_args, kw_args) = _parse_macro_arguments(tuple(),(:label,), args...)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.TextBox,
                                positional_args, kw_args)
end

export TextBox
export @TextBox