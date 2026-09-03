
mutable struct CoordinatesWidget <: ImGuiWidgetDNA
    _widget::ImGuiWidget
    _gizmo::GizmoRenderer

    _posX::Int
    _posY::Int
    
    _width::Int
    _height::Int

    _padding::Int

    function CoordinatesWidget(gizmo::GizmoRenderer)
        new(ImGuiWidget(),gizmo,0,0,0,0,0)
    end
end

_ImGuiWidget_(self::CoordinatesWidget)::ImGuiWidget = return self._widget

function format_float(x::Real,n::Integer)
    sign_str = x < 0 ? "-" : ""
    x_abs = abs(x)
    int_part = trunc(Int, x_abs)
    frac_part = round(Int, (x_abs - int_part) * 10^n)
    if frac_part == 10^n
        int_part += 1
        frac_part = 0
    end
    frac_str = lpad(string(frac_part), n, '0')
    return sign_str * string(int_part) * "." * frac_str
end

function render(self::CoordinatesWidget, app::AppDNA)
    imgui = getImGui(app)

    if (self._gizmo.axes > 0)
        CImGui.SetNextWindowPos((self._posX,self._posY))
        CImGui.SetNextWindowSize((self._width,self._height))

        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowRounding,5.0)
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowPadding,(self._padding,self._padding))

        CImGui.Begin("CoordinatesWidget",C_NULL,
            CImGui.ImGuiWindowFlags_NoSavedSettings | 
            CImGui.ImGuiWindowFlags_NoResize | CImGui.ImGuiWindowFlags_NoMove |
            CImGui.ImGuiWindowFlags_NoTitleBar | CImGui.ImGuiWindowFlags_NoCollapse |
            CImGui.ImGuiWindowFlags_NoDecoration)

        coords = "(" * format_float(self._gizmo.position[1],4) * ", " *
                       format_float(self._gizmo.position[2],4) * ", " *
                       format_float(self._gizmo.position[3],4) * ")"
        CImGui.Text(coords)
        
        CImGui.End()
        CImGui.PopStyleVar(2)
    end
end

function resize!(self::CoordinatesWidget,x::Int,y::Int)
    self._posX = 10
    self._posY = y - 40

    plusDigits = 0
    plusDigits += floor(Int, log10(max(1.0, abs(self._gizmo.position[1]))))
    if (self._gizmo.position[1] < 0) plusDigits += 1 end
    plusDigits += floor(Int, log10(max(1.0, abs(self._gizmo.position[2]))))
    if (self._gizmo.position[2] < 0) plusDigits += 1 end
    plusDigits += floor(Int, log10(max(1.0, abs(self._gizmo.position[3]))))
    if (self._gizmo.position[3] < 0) plusDigits += 1 end

    self._width = 163 + plusDigits * 6
    self._height = 20

    self._padding = 8
end