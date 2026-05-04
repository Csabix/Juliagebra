
# ? ---------------------------------
# ! SliderDependent
# ? ---------------------------------

mutable struct SliderDependent <: GuiDependentDNA
    _dependent::GuiDependent
    _value::Vec3F # ? x is minVal, y is currVal, z is maxVal

    # YELLOW Thread
    function SliderDependent(callback::Function, dependents::Vector{<:DependentDNA},label::String)
        dependent = GuiDependent(callback,dependents,label)
        value = Vec3FNan

        new(dependent,value)
    end
end

_GuiDependent_(self::SliderDependent)::GuiDependent = return self._dependent

# YELLOW Thread
# RED Thread
onNodeEval(self::SliderDependent) = evalCallbackDp(self)

Base.eltype(dependent::SliderDependent)::DataType = Float64

evalCallbackDpEntry(self::SliderDependent)::Float64 = return Float64(self._value.y)

evalCallbackDpReturn(self::SliderDependent, v::Vec3F) = self._value = v

# ? ---------------------------------
# ! SliderRenderer
# ? ---------------------------------

mutable struct SliderRenderer <: GuiRendererDNA{SliderDependent}
    _guiRenderer::GuiRenderer{SliderDependent}

    # GREEN Thread
    function SliderRenderer()
        guiRenderer = GuiRenderer{SliderDependent}()

        new(guiRenderer)
    end
end

_GuiRenderer_(self::SliderRenderer) = return self._guiRenderer

# GREEN Thread
added!(self::SliderRenderer,item::SliderDependent) = return nothing

# GREEN Thread
sync!(self::SliderRenderer,item::SliderDependent) = return nothing

# GREEN Thread
syncAll!(self::SliderRenderer) = return nothing

# GREEN Thread
addedAll!(self::SliderRenderer) = return nothing

function render!(self::SliderRenderer)
    CImGui.Text("SliderDependents:")
    CImGui.Separator()

    for sliderIdx in eachindex(getObservedItems(self))
        slider = self[sliderIdx]
        label = getLabel(slider)

        minVal = slider._value.x
        currVal = slider._value.y
        maxVal = slider._value.z

        proposedVal = slider1(currVal,"$(label)##$(sliderIdx)",minVal,maxVal)

        if(!isnothing(proposedVal))
            # ! Take into note, that the user can only click on one element at every frame,
            # ! so multiple evalGraph calls under a single frame can't happen!
            slider._value = Vec3F(minVal,proposedVal,maxVal)
            evalGraph(slider)
        end

    end
end

# ? ---------------------------------
# ! Slider
# ? ---------------------------------

# YELLOW Thread
Slider(; label="") =
build!(SliderDependent(Vector{DependentDNA}(),label) do 
    return Vec3F(0.0,0.5,1.0)    
end)

# YELLOW Thread
Slider(maxVal::Real; label="") =
build!(SliderDependent(Vector{DependentDNA}(),label) do 
    return Vec3F(0.0,maxVal/2.0,abs(maxVal))    
end)

# YELLOW Thread
Slider(minVal::Real, maxVal::Real; label="") =
build!(SliderDependent(Vector{DependentDNA}(),label) do 
    return Vec3F(minVal,((maxVal-minVal)/2.0)+minVal,maxVal)    
end)

# YELLOW Thread
Slider(minVal::Real, currVal::Real, maxVal::Real; label="") =
build!(SliderDependent(Vector{DependentDNA}(),label) do 
    return Vec3F(minVal,currVal,maxVal)    
end)

# YELLOW Thread
Slider(callback::Function,dependents::Vector{<:DependentDNA}; label="") =
build!(SliderDependent(callback,dependents,label))

macro Slider(callback::Expr, kw_args...)
    parsed_kw_args = _parse_macro_kw_args([:label], kw_args...)
    _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.Slider; parsed_kw_args...)
end

export Slider
export @Slider