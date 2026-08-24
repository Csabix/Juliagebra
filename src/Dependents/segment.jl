
# ? ---------------------------------
# ! Segment node
# ? ---------------------------------

struct SegmentDrawData
    handle::UInt32
    colors::Vector{UInt32}
    style::UInt8
    size::Float32
end

convert_callback_result(::PSegment, result::PSegment)           = result
convert_callback_result(::PSegment, result::LinePrimitive)      = PSegment(p0(result),p1(result))
convert_callback_result(::PSegment, result::Tuple{Vec3D,Vec3D}) = PSegment(result[1],result[2])
convert_callback_result(::PSegment, ::Nothing)                  = PSegment(Vec3DNan,Vec3DNan)

function render_node(segment::PSegment, data::SegmentDrawData, renderers::Dict{DataType,Renderer}, id::UInt32)::SegmentDrawData
    line_renderer::LineRenderer = renderers[LineRenderer]
    values = [segment.p0, segment.p1]
    if data.handle == 0
        handle = add!(line_renderer, values, Iterators.cycle(data.colors), Iterators.cycle(id), data.size, data.style)
        return SegmentDrawData(handle, data.colors, data.style, data.size)
    else
        update_coords!(line_renderer, data.handle, values)
        return data
    end
end

# ? ---------------------------------
# ! Segment intersection
# ? ---------------------------------

struct PSegmentOfSegment <: PrimitivesOf{PSegment}
    segment::PSegment
end
PrimitivesOf(self::PSegment) = PSegmentOfSegment(self)

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
    return add_node!(callback, PSegment(Vec3DNan,Vec3DNan); draw_data=draw_data, parents=parents)
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
    
    return Segment(l -> l,[_get_parent_segment(line)],color_style;color=color,style=style,size=size)
end

export Segment
