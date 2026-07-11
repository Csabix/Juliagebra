mutable struct DarkThemeWindow <: WindowDNA
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

    #These values are for testing purposes.
    function DarkThemeWindow(oBgColor,pRenderer::PointRenderer,lRenderer::LineRenderer,tRenderer::TriangleRenderer,sRenderer::SphereRenderer,) 
        new(Window(),
        false,
        lRenderer,
        pRenderer,
        sRenderer,
        tRenderer,
        Cfloat[oBgColor[1],oBgColor[2],oBgColor[3]],
        Cfloat[0.2f0,0.2f0,0.2f0],
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
        glClearColor(self._oBgColor[1], self._oBgColor[2], self._oBgColor[3], 1.0f0)
        #update_colors!(self._lRend,,)
        #update_colors!(self._pRend,,)
        #update_color!(self._tRend,,)
    end 
    update!(getOpenGL(app), app._cam, true, UInt32(0))
end


function renderContent(self::DarkThemeWindow, app::AppDNA)
    if (CImGui.Checkbox("Dark Theme", self._themeSwitch))
        setTheme(self,app)
    end
end