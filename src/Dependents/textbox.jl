# ? ---------------------------------
# ! TextBoxPlan
# ? ---------------------------------

mutable struct TextBoxPlan <:GuiPlanDNA
    _plan::GuiPlan

    _text::String

    function TextBoxPlan(callback::Function,plans::Vector{T},text) where {T<:PlanDNA}
        
        plan = GuiPlan(callback,plans)

        text = String(text)

        new(plan,text)
    end
end

_GuiPlan_(self::TextBoxPlan)::GuiPlan = return self._plan

# ? ---------------------------------
# ! TextBoxDependent
# ? ---------------------------------

mutable struct TextBoxDependent <: GuiDependentDNA
    _dependent::GuiDependent
    
    _text::String

    function TextBoxDependent(plan::TextBoxPlan)
        
        dependent = GuiDependent(plan)
        text = plan._text

        textBox = new(dependent,text)
        onNodeEval(textBox)
        return textBox
    end
end

_GuiDependent_(self::TextBoxDependent)::GuiDependent = return self._dependent

getSliderField(self::TextBoxDependent,fieldVal::Val{:text}) = return self._text
Base.getindex(self::TextBoxDependent,fieldSymbol::Symbol) = return getSliderField(self,Val(fieldSymbol))

onNodeEval(self::TextBoxDependent) = dpEvalCallback(self)
evalCallback(self::TextBoxDependent) = getCallback(self)(getGraphParents(self)...)
dpCallbackReturn(self::TextBoxDependent, text::String) = self._text = text
dpCallbackReturn(self::TextBoxDependent, ::Nothing) = return nothing

# ? ---------------------------------
# ! TextBoxRenderer
# ? ---------------------------------

mutable struct TextBoxRenderer <: GuiRendererDNA{TextBoxDependent}
    _guiRenderer::GuiRenderer{TextBoxDependent}

    function TextBoxRenderer()
        guiRenderer = GuiRenderer{TextBoxDependent}()

        new(guiRenderer)
    end
end

_GuiRenderer_(self::TextBoxRenderer) = return self._guiRenderer

added!(self::TextBoxRenderer,item::TextBoxDependent) = return nothing
sync!(self::TextBoxRenderer,item::TextBoxDependent) = return nothing
syncAll!(self::TextBoxRenderer) = return nothing
addedAll!(self::TextBoxRenderer) = return nothing

function render!(self::TextBoxRenderer)
    CImGui.Text("TextBoxDependents:")
    CImGui.Separator()

    for textBoxIdx in eachindex(getObservedItems(self))
        textBox = self[textBoxIdx]
        
        CImGui.Text("TextBox[$(textBoxIdx)]:")
        proposedText = txtbox("##TextBox[$(textBoxIdx)]",textBox._text)

        if (!isnothing(proposedText))
            textBox._text = proposedText
        end

        if (CImGui.Button("Apply TextBox[$(textBoxIdx)]"))
            # ! Take into note, that the user can only click on one element at every frame,
            # ! so multiple evalGraph calls under a single frame can't happen! 
            evalGraph(textBox)
        end
    end
end

function Plan2Observer(self::ImGuiData,plan::TextBoxPlan)
    return SingleGuiRendererByGuiDependentsWindow(self,TextBoxRenderer)
end

function Plan2Dependent(plan::TextBoxPlan)
    return TextBoxDependent(plan)
end