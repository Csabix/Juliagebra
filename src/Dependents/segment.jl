
# ? ---------------------------------
# ! Segment node
# ? ---------------------------------

mutable struct Segment
    primitive::PSegment

    function Segment()
        new(PSegment(Vec3DNan, Vec3DNan))
    end
end

struct SegmentDrawData
    handle::UInt32
    colors::Vector{UInt32}
    style::UInt8
    size::Float32
end

convert_callback_entry(segment::Segment)::Segment = segment

convert_result(segment::Segment, result::PSegment)::PSegment = segment.primitive = result
convert_result(segment::Segment, result::Tuple{Vec3D,Vec3D}) = segment.primitive = PSegment(result[1],result[2])
convert_result(segment::Segment, ::Nothing)                  = segment.primitive = PSegment(Vec3DNan,Vec3DNan)

function eval_node(segment::Segment, callback::Function, arguments::Vector{Any})::Any
    convert_result(segment, callback(arguments...))
    return segment
end

function render_node(segment::Segment, data::SegmentDrawData, renderers::Dict{DataType,Renderer}, id::UInt32)::SegmentDrawData
    line_renderer::LineRenderer = renderers[LineRenderer]
    values = [segment.primitive.p0, segment.primitive.p1]
    if data.handle == 0
        handle = add!(line_renderer, values, Iterators.cycle(data.colors), Iterators.cycle(id), data.size, data.style)
        return SegmentDrawData(handle, data.colors, data.style, data.size)
    else
        update_coords!(line_renderer, data.handle, values)
        return data
    end
end

p0(segment::Segment)::Vec3D = p0(segment.primitive)
p1(segment::Segment)::Vec3D = p1(segment.primitive)
v(segment::Segment)::Vec3D  = v(segment.primitive)

# ? ---------------------------------
# ! Segment intersection
# ? ---------------------------------

struct PSegmentOfSegment <: PrimitivesOf{PSegment}
    segment::PSegment
end
PrimitivesOf(self::Segment) = PSegmentOfSegment(self.primitive)

Base.length(self::PSegmentOfSegment) = 1
Base.iterate(self::PSegmentOfSegment, index::Integer = 1) = index == 1 ? (self.segment, (index + 1)) : nothing

# ? ---------------------------------
# ! Segment constructors
# ? ---------------------------------

_get_parent_segment(parent::NodeHandle) = parent
_get_parent_segment(parent) = add_node!(Vec3D(parent))

function Segment(callback::Function, parents::Union{Vector{NodeHandle},Nothing}=nothing, color_style::Union{Nothing,String}=nothing;
    color="c", style="-", size::Union{AbstractFloat,Integer}=5.0f0)
    (c, s) = parse_line_colors_style(color_style, color, style)
    draw_data = SegmentDrawData(UInt32(0), c, s, convert(Float32, size))
    return add_node!(callback, Segment(); draw_data=draw_data, parents=parents)
end

function Segment(p0,p1,color_style::Union{Nothing,String}=nothing;
    color="c",style="-",size::Union{AbstractFloat,Integer}=5.0f0)
    
    parents = NodeHandle[
        _get_parent_segment(p0),
        _get_parent_segment(p1),
    ]
    
    return Segment(parents,color_style;color=color,style=style,size=size) do p0,p1
        return (p0,p1)
    end
end

function Segment(line,color_style::Union{Nothing,String}=nothing;
    color="c",style="-",size::Union{AbstractFloat,Integer}=5.0f0)
    
    return Segment([_get_parent_segment(line)],color_style;color=color,style=style,size=size) do line
        return (p0(line),p1(line))
    end
end

export Segment