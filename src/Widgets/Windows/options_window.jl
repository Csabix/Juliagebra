
mutable struct OptionsWindow <: WindowDNA
    _window::Window

    _whitebg::Ref{Bool}
    _bgColor::UInt32

    function OptionsWindow(color)
        new(Window(), false, colorFloatsToUInt(color))
    end
end

_Window_(self::OptionsWindow)::Window = self._window
getWindowName(self::OptionsWindow) = "Options"

function setBackground(self::OptionsWindow, app::AppDNA)
    openglD::OpenGLData = getOpenGL(app)
    if (self._whitebg[])
        glClearColor(1.0f0, 1.0f0, 1.0f0, 1.0f0)
    else
        openglD._backgroundCol = colorUIntToFloats(self._bgColor)
        println(openglD._backgroundCol)
        glClearColor(openglD._backgroundCol[1], openglD._backgroundCol[2], openglD._backgroundCol[3], 1.0f0)
    end
end

function renderContent(self::OptionsWindow, app::AppDNA)
    if (CImGui.Checkbox("White background", self._whitebg))
        setBackground(self, app)
    end

    CImGui.Text("Background color")
    new_color = color_edit3(self._bgColor, "Background color")
    if (new_color !== nothing)
        self._bgColor = new_color
        setBackground(self, app)
    end
end

function colorFloatsToUInt(color::Vec3F)
    r = round(UInt32, color[1] * 255)
    g = round(UInt32, color[2] * 255)
    b = round(UInt32, color[3] * 255)
    return (r * 256^2) + (g * 256) + b
end

function colorUIntToFloats(color::UInt32)
    r = Float32(color & 255) / 255
    g = Float32(round(UInt32, color / 256) & 255) / 255
    b = Float32(round(UInt32, color / 256^2) & 255) / 255
    return Vec3F(r, g, b)
end
