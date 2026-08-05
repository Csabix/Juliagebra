
mutable struct OptionsWidget <: ImGuiWidgetDNA
    _widget::ImGuiWidget
    _window::WindowDNA

    _posX::Int
    _posY::Int
    
    _width::Int
    _height::Int

    _padding::Int

    function OptionsWidget(bgcolor,aabbMin,aabbMax)
        new(ImGuiWidget(),OptionsWindow(bgcolor,aabbMin,aabbMax),0,0,0,0,0)
    end
end

_ImGuiWidget_(self::OptionsWidget)::ImGuiWidget = return self._widget

function render(self::OptionsWidget, app::AppDNA)
    imgui = getImGui(app)

    CImGui.SetNextWindowPos((self._posX,self._posY))
    CImGui.SetNextWindowSize((self._width,self._height))

    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowRounding,11.0)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameRounding,6.0)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowPadding,(self._padding,self._padding))

    CImGui.Begin("OptionsWidget",C_NULL,
        CImGui.ImGuiWindowFlags_NoSavedSettings | 
        CImGui.ImGuiWindowFlags_NoResize | CImGui.ImGuiWindowFlags_NoMove |
        CImGui.ImGuiWindowFlags_NoTitleBar | CImGui.ImGuiWindowFlags_NoCollapse |
        CImGui.ImGuiWindowFlags_NoDecoration)

    CImGui.PushFont(imgui._iconFont,24)
    buttonSize::Tuple{Int,Int} = floor.((self._width,self._height) .- self._padding*2)

    # ? Options button
    if (CImGui.Button("\uE1AD",buttonSize))
        toggle!(self._window)
    end

    CImGui.PopFont()
    
    CImGui.End()
    CImGui.PopStyleVar(3)

    render(self._window, app)
end

function resize!(self::OptionsWidget,x::Int,y::Int)
    self._posX = 50
    self._posY = 5

    self._width = 40
    self._height = 40

    self._padding = 5
end