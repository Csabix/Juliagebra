const LINE_N_LENGTH = ceil(Int16, log(4, 1000))
const LINE_RANGE = range(-LINE_N_LENGTH, LINE_N_LENGTH, 2*LINE_N_LENGTH + 1)

# ? ---------------------------------
# ! Line node
# ? ---------------------------------

struct LineDrawData
    handle::UInt32
    colors::Vector{UInt32}
    style::UInt8
    size::Float32
end

convert_callback_result(::PLine, result::PLine)              = result
convert_callback_result(::PLine, result::LinePrimitive)      = PLine(p0(result),p1(result))
convert_callback_result(::PLine, result::Tuple{Vec3D,Vec3D}) = PLine(result[1],result[2])
convert_callback_result(::PLine, ::Nothing)                  = PLine(Vec3DNan,Vec3DNan)

function render_node(line::PLine, data::LineDrawData, renderers::Dict{DataType,Renderer}, id::UInt32)::LineDrawData
    line_renderer::LineRenderer = renderers[LineRenderer]

    p = line.p0
    v = normalize(line.p1 - p)
    values = [p + v * sign(t) * 4^abs(t) for t in LINE_RANGE]

    if data.handle == 0
        handle = add!(line_renderer, values, Iterators.cycle(data.colors), Iterators.cycle(id), data.size, data.style)
        return LineDrawData(handle, data.colors, data.style, data.size)
    else
        update_coords!(line_renderer, data.handle, values)
        return data
    end
end

# ? ---------------------------------
# ! Line intersection
# ? ---------------------------------

struct PLineOfLine <: PrimitivesOf{PLine}
    line::PLine
end
PrimitivesOf(self::PLine) = PLineOfLine(self)

Base.length(self::PLineOfLine) = 1
Base.iterate(self::PLineOfLine, index::Integer = 1) = index == 1 ? (self.line, (index + 1)) : nothing

# ? ---------------------------------
# ! Line constructors
# ? ---------------------------------

_get_parent_line(parent::NodeHandle) = parent
_get_parent_line(parent) = add_node!(Vec3D(parent))

function Line(callback::Function, parents::Union{Vector{NodeHandle},Nothing}=nothing, color_style::Union{Nothing,String}=nothing;
    color="g", style="-", size::Union{AbstractFloat,Integer}=3.0f0)
    (c, s) = parse_line_colors_style(color_style, color, style)
    draw_data = LineDrawData(UInt32(0), c, s, convert(Float32, size))
    return add_node!(callback, PLine(Vec3DNan,Vec3DNan); draw_data=draw_data, parents=parents)
end

function Line(p0,p1,color_style::Union{Nothing,String}=nothing;
    color="g",style="-",size::Union{AbstractFloat,Integer}=3.0f0)

    parents = NodeHandle[
        _get_parent_line(p0),
        _get_parent_line(p1),
    ]

    return Line(parents,color_style;color=color,style=style,size=size) do p0,p1
        return (p0,p1)
    end
end

function Line(line,color_style::Union{Nothing,String}=nothing;
    color="g",style="-",size::Union{AbstractFloat,Integer}=3.0f0)

    return Line(l -> l,[_get_parent_line(line)],color_style;color=color,style=style,size=size)
end

export Line
