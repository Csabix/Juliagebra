
mutable struct Dock <: ImGuiWidgetDNA
    _widget::ImGuiWidget
    
    _width::Int
    _height::Int

    # ! 0,0 is upper left corner
    _posX::Int
    _posY::Int

    _collapsedPosX::Int
    _collapsedPosY::Int

    _windows::Vector{WindowDNA}

    function Dock(windowWidth::Int, windowHeight::Int)
        widget = ImGuiWidget()
        
        dimensions = _northAnchoredDockDimensions(windowWidth,windowHeight)

        windows = Vector{WindowDNA}()

        new(widget,dimensions...,windows)
    end
end

_ImGuiWidget_(self::Dock)::ImGuiWidget = return self._widget

function _southAnchoredDockDimensions(windowWidth::Int, windowHeight::Int)
    width = floor(windowWidth/1.3)
    height = 70
    posX = floor(windowWidth/2 - width/2)
    posY = floor(windowHeight - height) - 5
    collapsedPosX = posX
    collapsedPosY = posY + height
    
    return (width,height,posX,posY,collapsedPosX,collapsedPosY)
end

function _northAnchoredDockDimensions(windowWidth::Int, windowHeight::Int)
    width = floor(windowWidth/1.3)
    height = 70
    posX = floor(windowWidth/2 - width/2)
    posY = 5
    collapsedPosX = posX
    collapsedPosY = 0

    return (width,height,posX,posY,collapsedPosX,collapsedPosY)
end

function render(self::Dock)
    
    CImGui.SetNextWindowSize((self._width,self._height))

    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowRounding,11.0)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FrameRounding,6.0)
    
    #CImGui.ImGuiWindowFlags_NoTitleBar
    CImGui.Begin("Dock",C_NULL,
        CImGui.ImGuiWindowFlags_NoResize | CImGui.ImGuiWindowFlags_NoMove | 
        CImGui.ImGuiWindowFlags_HorizontalScrollbar) 
    
    if (CImGui.IsWindowCollapsed())
        CImGui.SetWindowPos((self._collapsedPosX,self._collapsedPosY))
    else
        CImGui.SetWindowPos((self._posX,self._posY))
    end

    for window in self._windows
        CImGui.SameLine()
        
        windowName = getWindowName(window)
        size = getButtonSize(windowName) .* 1.15

        if(CImGui.Button(windowName,size))
            toggle!(window)
        end
    end

    CImGui.End()
    
    CImGui.PopStyleVar(2)

    for window in self._windows
        render(window)
    end
end

function add!(self::Dock,window::WindowDNA)
    push!(self._windows,window)
end

function resize!(self::Dock,windowWidth::Int,windowHeight::Int)
    width,height,posX,posY,collapsedPosX,collapsedPosY = _northAnchoredDockDimensions(windowWidth,windowHeight)
    
    self._width = width
    self._height = height
    self._posX = posX
    self._posY = posY
    self._collapsedPosX = collapsedPosX
    self._collapsedPosY = collapsedPosY
end