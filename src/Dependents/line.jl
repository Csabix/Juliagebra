const LINE_N_LENGTH = ceil(Int16, log(4, 1000))
const LINE_RANGE = range(-LINE_N_LENGTH, LINE_N_LENGTH, 2*LINE_N_LENGTH + 1)

# ? ---------------------------------
# ! Line node
# ? ---------------------------------

mutable struct Line
    primitive::PLine
    handle::NodeHandle
    
    values::Vector{Vec3D}
    colors::Vector{UInt32}
    style::UInt8
    size::Float32

    function Line(colors::Vector{UInt32},style::UInt8,size::Union{AbstractFloat,Integer})
        values = Vector{Vec3D}(undef, length(LINE_RANGE))
        new(PLine(Vec3DNan,Vec3DNan), UInt32(0), values, colors, style, convert(Float32,size))
    end
end

# convert_callback_entry(line::Line)::Tuple{Vec3D,Vec3D} = (line.primitive.p0, line.primitive.p1)
convert_callback_entry(line::Line)::Line = line

convert_result(line::Line, result::PLine)::PLine       = line.primitive = result
convert_result(line::Line, result::Tuple{Vec3D,Vec3D}) = line.primitive = PLine(result[1],result[2])
convert_result(line::Line, ::Nothing)                  = line.primitive = PLine(Vec3DNan,Vec3DNan)

function eval_node(line::Line, callback::Function, arguments::Vector{Any})::Any
    convert_result(line, callback(arguments...))

    for index in eachindex(LINE_RANGE)
        t = LINE_RANGE[index]
        p = line.primitive.p0
        v = normalize(line.primitive.p1 - p)
        line.values[index] = p + v * sign(t) * 4^abs(t)
    end
    return line
end

function render_node(line::Line, renderers::Dict{DataType,Renderer}, id::UInt32)::Nothing
    line_renderer::LineRenderer = renderers[LineRenderer]
    if line.handle == 0
        line.handle = add!(line_renderer,line.values,Iterators.cycle(line.colors),Iterators.cycle(id),line.size,line.style)
    else
        update_coords!(line_renderer,line.handle,line.values)
    end
    return nothing
end

p0(line::Line)::Vec3D = p0(line.primitive)
p1(line::Line)::Vec3D = p1(line.primitive)
v(line::Line)::Vec3D  = v(line.primitive)

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
    color="g",style="-",size::Union{AbstractFloat,Integer}=3.0f0)
    (c,s) = parse_line_colors_style(color_style,color,style)
    return add_node!(callback, Line(c,s,size), parents)
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

    return Line([_get_parent_line(line)],color_style;color=color,style=style,size=size) do line
        return (p0(line),p1(line))
    end
end

export Line
export p0,p1,v
