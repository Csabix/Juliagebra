# ? ---------------------------------
# ! SliderPlan
# ? ---------------------------------

mutable struct SliderPlan <:GuiPlanDNA
    _plan::GuiPlan

    _minVal::Float32
    _startVal::Float32
    _maxVal::Float32

    function SliderPlan(callback::Function,plans::Vector{T},minVal,startVal,maxVal) where {T<:PlanDNA}
        
        plan = GuiPlan(callback,plans)

        minVal = Float32(minVal)
        startVal = Float32(startVal)
        maxVal = Float32(maxVal)

        new(plan,minVal,startVal,maxVal)
    end
end

_GuiPlan_(self::SliderPlan)::GuiPlan = return self._plan

# ? ---------------------------------
# ! SliderDependent
# ? ---------------------------------

mutable struct SliderDependent <: GuiDependentDNA
    _dependent::GuiDependent
    
    _minVal::Float32
    _currVal::Float32
    _maxVal::Float32

    function SliderDependent(plan::SliderPlan)
        
        dependent = GuiDependent(plan)
        minVal = plan._minVal
        currVal = plan._startVal
        maxVal = plan._maxVal

        slider = new(dependent,minVal,currVal,maxVal)
        onNodeEval(slider)
        return slider
    end
end

_GuiDependent_(self::SliderDependent)::GuiDependent = return self._dependent

getSliderField(self::SliderDependent,fieldVal::Val{:state}) = return self._currVal
Base.getindex(self::SliderDependent,fieldSymbol::Symbol) = return getSliderField(self,Val(fieldSymbol))


onNodeEval(self::SliderDependent) = evalCallbackDp(self)
evalCallbackDpEntry(self::SliderDependent)::Float64 = return Float64(self._currVal)

evalCallbackDpReturn(self::SliderDependent, currVal::Number) = self._currVal = clamp(Float32(currVal),self._minVal,self._maxVal)
evalCallbackDpReturn(self::SliderDependent, ::Nothing) = return nothing

# ? ---------------------------------
# ! SliderRenderer
# ? ---------------------------------

mutable struct SliderRenderer <: GuiRendererDNA{SliderDependent}
    _guiRenderer::GuiRenderer{SliderDependent}

    function SliderRenderer()
        guiRenderer = GuiRenderer{SliderDependent}()

        new(guiRenderer)
    end
end

_GuiRenderer_(self::SliderRenderer) = return self._guiRenderer

added!(self::SliderRenderer,item::SliderDependent) = return nothing
sync!(self::SliderRenderer,item::SliderDependent) = @log "Synced slider!" INFO
syncAll!(self::SliderRenderer) = return nothing
addedAll!(self::SliderRenderer) = return nothing

function render!(self::SliderRenderer)
    CImGui.Text("SliderDependents:")
    CImGui.Separator()

    for sliderIdx in eachindex(getObservedItems(self))
        slider = self[sliderIdx]

        currVal = slider[:state]
        proposedVal = slider1(currVal,"Slider[$(sliderIdx)]",slider._minVal,slider._maxVal)

        if(!isnothing(proposedVal))
            # ! Take into note, that the user can only click on one element at every frame,
            # ! so multiple evalGraph calls under a single frame can't happen!
            slider._currVal = proposedVal
            evalGraph(slider)
        end

    end
end

function Plan2Observer(self::ImGuiData,plan::SliderPlan)
    return SingleGuiRendererByGuiDependentsWindow(self,SliderRenderer)
end

function Plan2Dependent(plan::SliderPlan)
    return SliderDependent(plan)
end