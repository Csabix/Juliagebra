mutable struct DarkThemeWindow
    _window::Window
    _themeSwitch:: Ref{Bool}

    # o stands for original
    # d stands for dark
    _oBgColor::Array{Cfloat}
    _dBgColor::Array{Cfloat}

    _oPointColor::Array{Cfloat}
    _dPointColor::Array{Cfloat}

    _oCurveColor::Array{Cfloat}
    _dCurveColor::Array{Cfloat}

    _oTriangleColor::Array{Cfloat}
    _dTriangleColor::Array{Cfloat}

    _oSphereColor::Array{Cfloat}
    _dSphereColor::Array{Cfloat}

    function DarkThemeWindow(oBgColor,oPointColor,oCurveColor,oTriangleColor,oSphereColor) #These are the main colors of each primitive
        new(Window(),false,
        Cfloat[oBgColor[0],oBgColor[1],oBgColor[2]],
        Cfloat[1,2,3],
        Cfloat[oPointColor[0],oPointColor[1],oPointColor[2]],
        Cfloat[1,2,3],
        Cfloat[oCurveColor[0],oCurveColor[1],oCurveColor[2]],
        Cfloat[1,2,3],
        Cfloat[oTriangleColor[0],oTriangleColor[1],oTriangleColor[2]],
        Cfloat[1,2,3],
        Cfloat[oSphereColor[0],oSphereColor[1],oSphereColor[2]],
        Cfloat[1,2,3]) 
    end
end

_Window_(self::DarkThemeWindow)::Window = self._window
getWindowName(self::DarkThemeWindow) = "Theme Changer"

function setTheme(self::DarkThemeWindow, app::AppDNA)
    if (self._themeSwitch[])
        glClearColor(1.0f0, 1.0f0, 1.0f0, 1.0f0)
    else
        glClearColor(self._bgColor[1], self._bgColor[2], self._bgColor[3], 1.0f0)
    end 
    update!(getOpenGL(app), app._cam, true, UInt32(0))
end


function renderContent(self::DarkThemeWindow, app::AppDNA)
    if (CImGui.Checkbox("Dark Theme", _themeSwitch))
        setTheme(self,app)
    end
    CImGui.BeginDisabled(self._themeSwitch[])
end