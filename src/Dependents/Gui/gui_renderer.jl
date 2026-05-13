
# ? ---------------------------------
# ! GuiRendererDNA
# ? ---------------------------------

mutable struct GuiRenderer{T<:GuiDependentDNA} <: ObserverDNA{T}
    _observer::Observer{T}
    _imgui::ImGuiDNA
    
    function GuiRenderer{T}(imgui::ImGuiDNA) where {T}
        new{T}(Observer{T}(),imgui)
    end
end

_GuiRenderer_(self::GuiRendererDNA)::GuiRenderer = error("Missing func!")
_Observer_(self::GuiRendererDNA)::Observer = return _GuiRenderer_(self)._observer

getImGui(self::GuiRendererDNA)::ImGuiDNA = _GuiRenderer_(self)._imgui

function added!(self::GuiRendererDNA{T}, d::T) where {T}
    imgui::ImGuiData = getImGui(self)
    push!(imgui._dependents,d)
    _added!(self,d)
end

function _added!(self::GuiRendererDNA{T}, d::T) where {T}
    error("Missing func!")
end

render!(self::GuiRendererDNA) = error("Missing func!")
render!(self::GuiRendererDNA,app::AppDNA) = render!(self)
title(::GuiRendererDNA)::String = error("Missing func!")
