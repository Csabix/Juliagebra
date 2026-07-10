mutable struct DarkThemeWindow
    _window::Window
    _themeSwitch:: Ref{Bool}

    _lRend::LineRenderer
    _pRend::PointRenderer
    _sRend::SphereRenderer
    _tRend::TriangleRenderer

    # o stands for original
    # d stands for dark
    _oBgColor::Array{Cfloat}
    _dBgColor::Array{Cfloat}

    _oPointColors::Array{Cfloat}
    _dPointColor::Array{Cfloat}

    _oCurveColors::Array{Cfloat}
    _dCurveColor::Array{Cfloat}

    _oTriangleColors::Array{Cfloat}
    _dTriangleColor::Array{Cfloat}

    _oSphereColors::Array{Cfloat}
    _dSphereColor::Array{Cfloat}

    #These are values are for testing purposes.
    function DarkThemeWindow(oBgColor,lRenderer::LineRenderer,pRenderer::PointRenderer,sRenderer::SphereRenderer,tRenderer::TriangleRenderer) 
        new(Window(),
        false,
        lRenderer,
        pRenderer,
        sRenderer,
        tRenderer,
        Cfloat[oBgColor[0],oBgColor[1],oBgColor[2]],
        Cfloat[80.0f0,80.0f0,80.0f0],
        Cfloat[255.0f0,255.0f0,255.0f0],
        Cfloat[100.0f0,200.0f0,100.0f0],
        Cfloat[255.0f0,255.0f0,255.0f0],
        Cfloat[100.0f0,200.0f0,100.0f0],
        Cfloat[255.0f0,255.0f0,255.0f0],
        Cfloat[100.0f0,200.0f0,100.0f0],
        Cfloat[255.0f0,255.0f0,255.0f0],
        Cfloat[100.0f0,200.0f0,100.0f0])
    end
end

_Window_(self::DarkThemeWindow)::Window = self._window
getWindowName(self::DarkThemeWindow) = "Theme Changer"

function setTheme(self::DarkThemeWindow, app::AppDNA)
    if (self._themeSwitch[])
        #spheres can't change colors yet.
        glClearColor(self._dBgColor[1], self._dBgColor[2], self._dBgColor[3], 1.0f0)
        #update_colors!(self._lRend,,)
        #update_colors!(self._pRend,,)       
        #update_color!(self._tRend,,)


    else
        glClearColor(self._obgColor[1], self._obgColor[2], self._obgColor[3], 1.0f0)
        #update_colors!(self._lRend,,)
        #update_colors!(self._pRend,,)
        #update_color!(self._tRend,,)
    end 
    update!(getOpenGL(app), app._cam, true, UInt32(0))
end


function renderContent(self::DarkThemeWindow, app::AppDNA)
    if (CImGui.Checkbox("Dark Theme", _themeSwitch))
        setTheme(self,app)
    end
    CImGui.BeginDisabled(self._themeSwitch[])
end