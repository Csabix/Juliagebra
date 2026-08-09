@enum StyleType begin
    point_style
    pointset_style
    pointsequence_style
    parametriccurve_style
    parametricsurface_style
    sphere_style
    segmentsequence_style
    trianglecluster_style
    background_style
    ui_style
end

@enum UiType begin 
    dark 
    light 
    classic
end

abstract type Style end

mutable struct Theme
    _name::String
    _styles::Dict{StyleType,Any}
end

mutable struct PointStyle<:Style
    _color::Union{Nothing,UInt32}
    _style::Union{Nothing,UInt8}
    _size::Union{Nothing,UInt8}
end

mutable struct ParametricCurveStyle<:Style
    _color::Union{Nothing,UInt32}
    _style::Union{Nothing,UInt8}
    _size::Union{Nothing,Float32}
end

mutable struct ParametricSurfaceStyle<:Style
    _color::Union{Nothing,UInt32}
end

mutable struct SphereStyle<:Style
    _color::Union{Nothing,UInt32}
end

mutable struct SegmentSequenceStyle<:Style
    _color::Union{Nothing,UInt32}
    _style::Union{Nothing,UInt8}
    _size::Union{Nothing,Float32}
end

mutable struct TriangleClusterStyle<:Style
    _color::Union{Nothing,UInt32}
end

mutable struct UiStyle<:Style
    _style::Union{Nothing,UiType}
end

mutable struct BackGroundStyle<:Style
    _color::NTuple{3, Cfloat}
end

Themes = Vector{Theme}()

LIGHT_THEME = Theme(
    "Light",
    Dict{StyleType, Style}(
       point_style => PointStyle(get_color("m"), get_point_style("."), UInt8(25)),
       pointset_style => PointStyle(get_color("m"), get_point_style("."), UInt8(25)),
       pointsequence_style => PointStyle(get_color("m"), get_point_style("."), UInt8(25)),
       parametriccurve_style => ParametricCurveStyle(get_color("c"), get_style("-"), 5.0f0),
       parametricsurface_style => ParametricSurfaceStyle(get_color("g")),
       sphere_style => SphereStyle(get_color("b")),
       segmentsequence_style => SegmentSequenceStyle(get_color("c"), get_style("-"), 5.0f0),
       trianglecluster_style => TriangleClusterStyle(get_color("g")),
       ui_style => UiStyle(dark),
       background_style => BackGroundStyle((0.73f0,0.73f0,0.73f0))))

DARK_THEME = Theme(
    "Dark",
    Dict{StyleType, Style}(
       point_style => PointStyle(get_color("r"), get_point_style("."), UInt8(25)),
       pointset_style => PointStyle(get_color("r"), get_point_style("."), UInt8(25)),
       pointsequence_style => PointStyle(get_color("r"), get_point_style("."), UInt8(25)),
       parametriccurve_style => ParametricCurveStyle(get_color("b"), get_style("-"), 5.0f0),
       parametricsurface_style => ParametricSurfaceStyle(get_color("m")),
       sphere_style => SphereStyle(get_color("c")),
       segmentsequence_style => SegmentSequenceStyle(get_color("b"), get_style("-"), 5.0f0),
       trianglecluster_style => TriangleClusterStyle(get_color("m")),
       ui_style => UiStyle(dark),
       background_style => BackGroundStyle((0.15f0,0.15f0,0.15f0))))

push!(Themes,LIGHT_THEME)
push!(Themes,DARK_THEME)

function theme_style(theme::Theme, type::StyleType)
    theme._styles[type]
end

function setStyle!(theme::Theme, styleType::StyleType, style)
    theme._styles[styleType] = style
    return theme
end

get_style_color(style::Style) = isnothing(style._color) ? get_color("m") : style._color

get_style_style_point(style::Style) = isnothing(style._style) ? get_point_style(".") : style._style
get_style_style_line(style::Style) = isnothing(style._style) ? get_style("-") : style._style
get_style_style_ui(style::Style) = isnothing(style._style) ? dark : style._style

get_style_size_int(style::Style) = isnothing(style._size) ? UInt8(25) : style._size
get_style_size_float(style::Style) = isnothing(style._size) ? 5.0f0 : style._size