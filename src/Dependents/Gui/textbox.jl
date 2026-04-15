
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

evalCallbackDpEntry(self::TextBoxDependent)::String = return self._text   

evalCallbackDpReturn(self::TextBoxDependent, text::String) = self._text = text

# ? ---------------------------------
# ! TextBoxRenderer
# ? ---------------------------------

# TODO: copy Strings, instead of views!
mutable struct TextBoxRenderer <: GuiRendererDNA{TextBoxDependent}
    _guiRenderer::GuiRenderer{TextBoxDependent}

    # GREEN Thread
    TextBoxRenderer(imgui::ImGuiDNA) = new(GuiRenderer{TextBoxDependent}(imgui))
end

_GuiRenderer_(self::TextBoxRenderer) = return self._guiRenderer

# GREEN Thread
_added!(self::TextBoxRenderer,item::TextBoxDependent) = return nothing

# GREEN Thread
sync!(self::TextBoxRenderer,item::TextBoxDependent) = return nothing

# GREEN Thread
syncAll!(self::TextBoxRenderer) = return nothing

# GREEN Thread
addedAll!(self::TextBoxRenderer) = return nothing

title(::TextBoxRenderer)::String = return "TextBox"

function render!(self::TextBoxRenderer, textBox::TextBoxDependent, app::AppDNA)
    m::ModelDNA = getModel(app)
    s::Scheduler = getScheduler(m)
    label::String = getLabel(textBox)
    textBoxIdx::Int = getObserverID(textBox)

    if !(label == "")
        CImGui.Text("$(label)")
    end

    proposedText = txtbox("##$(textBoxIdx)",textBox._text)

    if (!isnothing(proposedText))
        textBox._text = proposedText
    end

    if (CImGui.Button("Apply $(label)##$(textBoxIdx)"))
        schedule(s,textBox)
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
macro TextBox(callback::Expr, kw_args...)
    parsed_kw_args = _parse_macro_kw_args([:label], kw_args...)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.TextBox; parsed_kw_args...)
end

export TextBox
export @TextBox