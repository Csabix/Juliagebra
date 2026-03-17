
# ? ---------------------------------
# ! ResetWidget
# ? ---------------------------------

mutable struct ResetWidget <: ImGuiWidgetDNA
    _imgui::ImGuiDNA
    _widget::ImGuiWidget

    _posX::Int
    _posY::Int
    
    _width::Int
    _height::Int

    function ResetWidget(imgui::ImGuiDNA)
        new(imgui,ImGuiWidget(),0,0,0,0)
    end
end

_ImGuiWidget_(self::ResetWidget)::ImGuiWidget = return self._widget

function render(self::ResetWidget)
    CImGui.SetNextWindowPos((self._posX,self._posY))
    CImGui.SetNextWindowSize((self._width,self._height))


    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowRounding,11.0)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameRounding,6.0)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowPadding,(6,6))
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing,(0,0))


    CImGui.Begin("ResetWidget",C_NULL,
        CImGui.ImGuiWindowFlags_NoSavedSettings | 
        CImGui.ImGuiWindowFlags_NoResize | CImGui.ImGuiWindowFlags_NoMove |
        CImGui.ImGuiWindowFlags_NoTitleBar | CImGui.ImGuiWindowFlags_NoCollapse |
        CImGui.ImGuiWindowFlags_NoDecoration)
    

    CImGui.PushFont(self._imgui._iconFont,24)
    
    ssize = (35,35)
    
    # ? Reset button
    if (CImGui.Button("\uE863",ssize))

    end
    CImGui.SameLine()
    # ? 
    if (CImGui.Button("\uE868",ssize))

    end
    # ? 
    if (CImGui.Button("\uE60E",ssize))

    end
    CImGui.SameLine()
    # ? 
    if (CImGui.Button("\uE51C",ssize))

    end

    CImGui.PopFont()
    
    CImGui.End()
    CImGui.PopStyleVar(4)
end

function resize!(self::ResetWidget,x::Int,y::Int)
    self._posX = 5
    self._posY = 5

    self._width = 82
    self._height = 82
end