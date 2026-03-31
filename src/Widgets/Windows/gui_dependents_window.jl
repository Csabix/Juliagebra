
# ? ---------------------------------
# ! GuiDependentsWindow
# ? ---------------------------------

@kwdef mutable struct GuiDependentsWindow <: WindowDNA
    _window::Window = Window()
    _isOrdered::Bool = false
end

_Window_(self::GuiDependentsWindow)::Window = self._window
getWindowName(self::GuiDependentsWindow) = return "GuiDependents"

function renderContent(self::GuiDependentsWindow, app::AppDNA)
    imgui::ImGuiData = getImGui(app)
    
    isOrderedRef = Ref(self._isOrdered)
    if (CImGui.Checkbox("Order by type",isOrderedRef))
        self._isOrdered = !self._isOrdered
    end
    CImGui.Separator()
    CImGui.Spacing()

    if self._isOrdered
        pool::Vector{GuiRendererDNA} = imgui._pool
        
        for observer in pool
            if hasInstance(observer)    
                CImGui.Text("$(title(observer)) dependents:")
                CImGui.Separator()

                for observed in getObservedItems(observer) 
                    CImGui.PushID(getGraphID(observed))
                    render!(observer, observed, app)
                    CImGui.PopID()
                end
            end
        end
    else
        dependents::Vector{GuiDependentDNA} = imgui._dependents

        for d in dependents
            CImGui.PushID(getGraphID(d))
            render!(getObserver(d),d,app)
            CImGui.PopID()
        end
    end
end
