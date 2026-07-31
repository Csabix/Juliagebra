@enum ThemeType::Int32 begin
    defaultTheme
    darkTheme
end

mutable struct Theme
    styles::Dict{Type,Any}
end

mutable struct PointStyle
    _color::String
    _style::String
    _size::UInt8
end

mutable struct ParametricCurveStyle
    _color::Vector{String}
    _style::String
    _size::Float32
end

mutable struct ParametricSurfaceStyle
    _color::String
end

mutable struct SphereStyle
    _color::String
end

mutable struct SegmentSequenceStyle
    _colors::Vector{String}
    _style::String
    _size::Float32
end

mutable struct TriangleClusterStyle
    _color::String
end

Themes = Vector{Theme}()

LIGHT_THEME = Theme(
    Dict(
       PointDependent => PointStyle("m", ".", UInt8(25)),
       PointSetDependent => PointStyle("m", ".", UInt8(25)),
       PointSequenceDependent => PointStyle("m", ".", UInt8(25)),
       ParametricCurveDependent => ParametricCurveStyle(["c"], "-", 5.0f0),
       ParametricSurfaceDependent => ParametricSurfaceStyle("g"),
       SphereDependent => SphereStyle("b"),
       SegmentSequenceDependent => SegmentSequenceStyle(["c"], "-", 5.0f0),
       TriangleClusterDependent => TriangleClusterStyle("g")))

DARK_THEME = Theme(
    Dict(
       PointDependent => PointStyle("r", ".", UInt8(25)),
       PointSetDependent => PointStyle("r", ".", UInt8(25)),
       PointSequenceDependent => PointStyle("r", ".", UInt8(25)),
       ParametricCurveDependent => ParametricCurveStyle(["b"], "-", 5.0f0),
       ParametricSurfaceDependent => ParametricSurfaceStyle("m"),
       SphereDependent => SphereStyle("c"),
       SegmentSequenceDependent => SegmentSequenceStyle(["b"], "-", 5.0f0),
       TriangleClusterDependent => TriangleClusterStyle("m")))

push!(Themes,LIGHT_THEME)
push!(Themes,DARK_THEME)

function resolve_theme(theme::Theme, dependent)
     return theme.styles[typeof(dependent)]
end



