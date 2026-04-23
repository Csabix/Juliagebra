function get_color(c::Tuple{<:Integer,<:Integer,<:Integer,<:Integer})::UInt32
    return  (UInt32(c[4]) << 24) |
            (UInt32(c[3]) << 16) |
            (UInt32(c[2]) << 8 ) |
            (UInt32(c[1]))
end

function get_color(c::Tuple{<:Integer,<:Integer,<:Integer})::UInt32
    return  (UInt32(255)  << 24) |
            (UInt32(c[3]) << 16) |
            (UInt32(c[2]) << 8 ) |
            (UInt32(c[1]))
end

function get_color(c::Tuple{<:AbstractFloat,<:AbstractFloat,<:AbstractFloat,<:AbstractFloat})::UInt32
    return get_color(map(e -> UInt32(round(clamp(e, 0.0, 1.0) * 255.0)),c))
end

function get_color(c::Tuple{<:AbstractFloat,<:AbstractFloat,<:AbstractFloat})::UInt32
    return get_color(map(e -> UInt32(round(clamp(e, 0.0, 1.0) * 255.0)),c))
end

function get_colors(c::Vector{T})::Vector{UInt32} where {T}
    return UInt32[get_color(color) for color in c]
end

function get_colors(c)::Vector{UInt32}
    return UInt32[get_color(c)]
end

const _color_name::Dict{String, UInt32} = Dict(
    "red"     => get_color((0xff,0x00,0x00)),
    "green"   => get_color((0x00,0xff,0x00)),
    "blue"    => get_color((0x00,0x00,0xff)),
    "cyan"    => get_color((0x00,0xff,0xff)),
    "magenta" => get_color((0xff,0x00,0xff)),
    "yellow"  => get_color((0xff,0xff,0x0)),
    "black"   => get_color((0x00,0x00,0x00)),
    "white"   => get_color((0xff,0xff,0xff))
)

const _color_name_short::Dict{Char, UInt32} = Dict(
    'r' => get_color((0xff,0x00,0x00)),
    'g' => get_color((0x00,0xff,0x00)),
    'b' => get_color((0x00,0x00,0xff)),
    'c' => get_color((0x00,0xff,0xff)),
    'm' => get_color((0xff,0x00,0xff)),
    'y' => get_color((0xff,0xff,0x0)),
    'k' => get_color((0x00,0x00,0x00)),
    'w' => get_color((0xff,0xff,0xff))
)

function get_color(color::String)::UInt32
    for (k,v) in _color_name
        if startswith(color,k)
            return v
        end
    end
    for (k,v) in _color_name_short
        if startswith(color,k)
            return v
        end
    end
    error("Invalid color value: $color")
end

const _line_style::Dict{AbstractString,UInt8} = Dict(
    "-"  => SOLID,
    "--" => DASHED,
    ":"  => DOTTED,
    "~"  => WAVE,
    "-." => DASH_DOT,
    "->" => ARROW,
    "<-" => ARROW_REVERSED
)

function get_style(style::UInt8)::UInt8
    return style
end

function get_style(style)::UInt8
    if haskey(_line_style, style)
        return _line_style[style]
    else
        return SOLID
    end
end

function color_line_combined(color_style::String)::Tuple{UInt32,UInt8}
    if isletter(color_style[1])
        return get_color(color_style), get_style(view(color_style,2:length(color_style)))
    else
        return get_color("c"), get_style(color_style)
    end
end

function get_color_vec3f(color)::Vec3F
    packed = get_color(color)
    return Vec3F(Float32( packed        & 0xff) / 255.0f0,
                 Float32((packed >>  8) & 0xff) / 255.0f0,
                 Float32((packed >> 16) & 0xff) / 255.0f0)
end
get_color_vec3f(color::Vec3F) = color

function parse_line_style_colors(color_style::Union{Nothing,String},color,style)::Tuple{UInt8,Vector{UInt32}}
    if isnothing(color_style)
        return get_style(style), get_colors(color)
    else
        (color, style) = color_line_combined(color_style)
        return style, UInt32[color]
    end
end

function unpack_color(c::UInt32)::Vec4F
    r = Float32( c        & 0xff) / 255.0f0
    g = Float32((c >>  8) & 0xff) / 255.0f0
    b = Float32((c >> 16) & 0xff) / 255.0f0
    a = Float32((c >> 24) & 0xff) / 255.0f0
    return Vec4F(r, g, b, a)
end