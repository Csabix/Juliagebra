
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

mutable struct TextBoxRenderer <: GuiRendererDNA{TextBoxDependent}
    _guiRenderer::GuiRenderer{TextBoxDependent}

    # GREEN Thread
    function TextBoxRenderer()
        guiRenderer = GuiRenderer{TextBoxDependent}()

        new(guiRenderer)
    end
end

_GuiRenderer_(self::TextBoxRenderer) = return self._guiRenderer

# GREEN Thread
added!(self::TextBoxRenderer,item::TextBoxDependent) = return nothing

# GREEN Thread
sync!(self::TextBoxRenderer,item::TextBoxDependent) = return nothing

# GREEN Thread
syncAll!(self::TextBoxRenderer) = return nothing

# GREEN Thread
addedAll!(self::TextBoxRenderer) = return nothing

function render!(self::TextBoxRenderer)
    CImGui.Text("TextBoxDependents:")
    CImGui.Separator()

    for textBoxIdx in eachindex(getObservedItems(self))
        textBox = self[textBoxIdx]
        label = getLabel(textBox)

        CImGui.Text("$(label)")
        proposedText = txtbox("##$(textBoxIdx)",textBox._text)

        if (!isnothing(proposedText))
            textBox._text = proposedText
        end

        if (CImGui.Button("Apply $(label)##$(textBoxIdx)"))
            # ! Take into note, that the user can only click on one element at every frame,
            # ! so multiple evalGraph calls under a single frame can't happen! 
            evalGraph(textBox)
        end
    end
end

# ? ---------------------------------
# ! TextBox
# ? ---------------------------------

# YELLOW Thread
TextBox(; label="") =
build!(TextBoxDependent(Vector{DependentDNA}(),label) do 
    return ""
end)

# YELLOW Thread
TextBox(text::String; label="") =
build!(TextBoxDependent(Vector{DependentDNA}(),label) do 
    return text
end)

# YELLOW Thread
TextBox(callback::Function, dependents::Vector{<:DependentDNA}; label="") =
build!(TextBoxDependent(callback,dependents,label))

# YELLOW Thread
macro TextBox(callback::Expr)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.TextBox)
end

export TextBox
export @TextBox