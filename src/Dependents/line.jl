const LINE_N_LENGTH = ceil(Int16, log(4, 1000))
const LINE_RANGE = range(-LINE_N_LENGTH, LINE_N_LENGTH, 2*LINE_N_LENGTH + 1)

# ? ---------------------------------
# ! Line node
# ? ---------------------------------

mutable struct Line
    primitive::PLine
    handle::NodeHandle
    
    range::AbstractRange{Float64}
    values::Vector{Vec3D}
    colors::Vector{UInt32}
    style::UInt8
    size::Float32

    function Line(primitive::PLine,colors::Vector{UInt32},style::UInt8,size::Float32)
        range = LINE_RANGE
        values = Vector{Vec3D}(undef, length(range))
        new(primitive, UInt32(0), range, values, colors, style, size)
    end
end

# convert_callback_entry(line::Line)::Tuple{Vec3D,Vec3D} = (line.primitive.p0, line.primitive.p1)
convert_callback_entry(line::Line)::Line = line

convert_result(result::Tuple{Vec3D,Vec3D})::PLine = PLine(result[1],result[2])
convert_result(result::PLine)::PLine = result
convert_result(::Nothing)::PLine = PLine(Vec3DNan,Vec3DNan)

function eval_node(element::Line, callback::Function, arguments::Vector{Any})::Any
    element.primitive = convert_result(callback(arguments...))

    for index in eachindex(element.range)
        t = element.range[index]
        p = element.primitive.p0
        v = normalize(element.primitive.p1 - p)
        element.values[index] = p + v * sign(t) * 4^abs(t)
    end
    return element
end

function render_node(line::Line, renderers::Dict{DataType,Renderer}, id::UInt32)::Nothing
    line_renderer::LineRenderer = renderers[LineRenderer]
    if line.handle == 0
        line.handle = add!(line_renderer,line.values,Iterators.cycle(line.colors),Iterators.cycle(id),5.0f0,line.style)
    else
        update_coords!(line_renderer,line.handle,line.values)
    end
    return nothing
end

# ? ---------------------------------
# ! Line intersection
# ? ---------------------------------

struct PLineOfLine <: PrimitivesOf{PLine}
    line::PLine
end
PrimitivesOf(self::Line) = PLineOfLine(self.primitive)

Base.length(self::PLineOfLine) = 1
Base.iterate(self::PLineOfLine, index::Integer = 1) = index == 1 ? (self.line, (index + 1)) : nothing

# ? ---------------------------------
# ! Line constructors
# ? ---------------------------------

_get_parent_line(parent::NodeHandle) = parent
_get_parent_line(parent) = add_node!(Vec3D(parent))

function Line(callback::Function,parents::Union{Vector{NodeHandle},Nothing}=nothing,color_style::Union{Nothing,String}=nothing;
    color="g",style="-",size=3.0f0)
    (c,s) = parse_line_colors_style(color_style,color,style)
    return add_node!(callback, Line(PLine(Vec3DNan,Vec3DNan),c,s,size), parents)
end

function Line(p0,p1,color_style::Union{Nothing,String}=nothing;
    color="g",style="-",size=3.0f0)

    parents = NodeHandle[
        _get_parent_line(p0),
        _get_parent_line(p1),
    ]

    (c,s) = parse_line_colors_style(color_style,color,style)
    return add_node!(Line(PLine(Vec3DNan,Vec3DNan),c,s,size), parents) do p0,p1
        return (p0,p1)
    end
end

export Line
