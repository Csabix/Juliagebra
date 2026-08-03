@enum StyleType begin
    point_style
    pointset_style
    pointsequence_style
    parametriccurve_style
    parametricsurface_style
    sphere_style
    segmentsequence_style
    trianglecluster_style
end

abstract type Style end

mutable struct Theme
    _name::String
    _styles::Dict{StyleType,Style}
end

mutable struct UiStyle<:Style
    _bgColor::Array{Cfloat}

end

mutable struct PointStyle<:Style
    _color::String
    _style::String
    _size::UInt8
end

mutable struct ParametricCurveStyle<:Style
    _color::Vector{String}
    _style::String
    _size::Float32
end

mutable struct ParametricSurfaceStyle<:Style
    _color::String
end

mutable struct SphereStyle<:Style
    _color::String
end

mutable struct SegmentSequenceStyle<:Style
    _colors::Vector{String}
    _style::String
    _size::Float32
end

mutable struct TriangleClusterStyle<:Style
    _color::String
end

Themes = Vector{Theme}()

LIGHT_THEME = Theme(
    "Light",
    Dict{StyleType, Style}(
       point_style => PointStyle("m", ".", UInt8(25)),
       pointset_style => PointStyle("m", ".", UInt8(25)),
       pointsequence_style => PointStyle("m", ".", UInt8(25)),
       parametriccurve_style => ParametricCurveStyle(["c"], "-", 5.0f0),
       parametricsurface_style => ParametricSurfaceStyle("g"),
       sphere_style => SphereStyle("b"),
       segmentsequence_style => SegmentSequenceStyle(["c"], "-", 5.0f0),
       trianglecluster_style => TriangleClusterStyle("g")))

DARK_THEME = Theme(
    "Dark",
    Dict{StyleType, Style}(
       point_style => PointStyle("r", ".", UInt8(25)),
       pointset_style => PointStyle("r", ".", UInt8(25)),
       pointsequence_style => PointStyle("r", ".", UInt8(25)),
       parametriccurve_style => ParametricCurveStyle(["b"], "-", 5.0f0),
       parametricsurface_style => ParametricSurfaceStyle("m"),
       sphere_style => SphereStyle("c"),
       segmentsequence_style => SegmentSequenceStyle(["b"], "-", 5.0f0),
       trianglecluster_style => TriangleClusterStyle("m")))

push!(Themes,LIGHT_THEME)
push!(Themes,DARK_THEME)

function theme_style(theme::Theme, type::StyleType)
    theme._styles[type]
end