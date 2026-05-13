
# ? ---------------------------------
# ! ResetWidget
# ? ---------------------------------

mutable struct ResetWidget <: ImGuiWidgetDNA
    _widget::ImGuiWidget

    _posX::Int
    _posY::Int
    
    _width::Int
    _height::Int

    _padding::Int

    function ResetWidget()
        new(ImGuiWidget(),0,0,0,0,0)
    end
end

_ImGuiWidget_(self::ResetWidget)::ImGuiWidget = return self._widget

function render(self::ResetWidget, app::AppDNA)
    imgui = getImGui(app)

    CImGui.SetNextWindowPos((self._posX,self._posY))
    CImGui.SetNextWindowSize((self._width,self._height))


    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowRounding,11.0)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameRounding,6.0)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowPadding,(self._padding,self._padding))
    #CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing,(0,0))


    CImGui.Begin("ResetWidget",C_NULL,
        CImGui.ImGuiWindowFlags_NoSavedSettings | 
        CImGui.ImGuiWindowFlags_NoResize | CImGui.ImGuiWindowFlags_NoMove |
        CImGui.ImGuiWindowFlags_NoTitleBar | CImGui.ImGuiWindowFlags_NoCollapse |
        CImGui.ImGuiWindowFlags_NoDecoration)
    

    CImGui.PushFont(imgui._iconFont,24)
    buttonSize::Tuple{Int,Int} = floor.((self._width,self._height) .- self._padding*2)

    # ? Reset button
    if (CImGui.Button("\uE863",buttonSize))
        putInternal!(getCommander(app),EmptySceneCommand())
    end

    CImGui.PopFont()
    
    CImGui.End()
    CImGui.PopStyleVar(3)
end

function resize!(self::ResetWidget,x::Int,y::Int)
    self._posX = 5
    self._posY = 5

    self._width = 40
    self._height = 40

    self._padding = 5
end