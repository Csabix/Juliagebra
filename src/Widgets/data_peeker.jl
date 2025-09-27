
mutable struct DataPeeker <: WindowDNA
    _window::Window
    _shrd::SharedData

    function DataPeeker(shrd::SharedData)
        window = Window()
        new(window,shrd)
    end
end

_Window_(self::DataPeeker)::Window = self._window
getWindowName(self::DataPeeker) = return "DataPeeker"

function renderContent(self::DataPeeker)
    
    if CImGui.BeginTabBar("Places")
        if CImGui.BeginTabItem("Shared Data")
            _display!(self,self._shrd)
            CImGui.EndTabItem()
        end
        CImGui.EndTabBar()
    end

end

function _display!(self::DataPeeker,shrd::SharedData)
    CImGui.Text("Selected ID: $(shrd._selectedID)")
    CImGui.Text("Cursor Pos: ($(shrd._mouseX),$(shrd._mouseY))")
    CImGui.Text("Relative cursor: ($(shrd._relMouseX),$(shrd._relMouseY))")
    CImGui.Text("Cursor moved: $(shrd._mouseMoved)")
    CImGui.Text("Window Dimensions: ($(shrd._width),$(shrd._height))")
    CImGui.Text("Delta Time: $(shrd._deltaTime)")

    fpsApprx = 1.0/shrd._deltaTime

    CImGui.Text("FPS approx: $(fpsApprx)")

    #shrd._selectedGizmo = slider1i(shrd._selectedGizmo,"GizmoID",1,3)

end
