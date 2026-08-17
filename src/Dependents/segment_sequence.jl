mutable struct SegmentSequence
    values::Vector{Vec3D}

    function SegmentSequence()
        new(Vector{Vec3D}())
    end
end

struct SegmentSequenceDrawData
    handle::UInt32
    colors::Vector{UInt32}
    break_every::Int32
    size::Float32
    style::UInt8
end

convert_callback_entry(s::SegmentSequence)::Vec3D = s.values

function convert_callback_result(s::SegmentSequence,coords::Vector{T}) where T <: Tuple{Any, Any, Any}
    s.values = [Vec3D(coord...) for coord in coords]
    return s
end
function convert_callback_result(s::SegmentSequence,coords::Vector{T}) where T <: Tuple{Any, Any}
    s.values = [Vec3D(coord...,0.0) for coord in coords]
    return s
end
convert_callback_result(s::SegmentSequence,coords::Vector{Vec3D})  = (s.values = coords; s)
convert_callback_result(s::SegmentSequence,coords::Vector{Vec2D})  = (s.values = [Vec3D(coord...,0.0) for coord in coords]; s)
convert_callback_result(s::SegmentSequence,coords::Vector{Vec3F})  = (s.values = [Vec3D(coord...) for coord in coords]; s)
convert_callback_result(s::SegmentSequence,coords::Vector{Vec2F})  = (s.values = [Vec3D(coord...,0.0) for coord in coords]; s)
convert_callback_result(s::SegmentSequence,coords::Vector{Vector}) = (s.values = [length(c) == 3 ? Vec3D(c[1],c[2],c[3]) : Vec3D(c[1],c[2],0.0) for c in coords]; s)
convert_callback_result(s::SegmentSequence,::Nothing) = (s.values = Vec3D[];s)

struct PSegmentsOfSegmentSequence <: PrimitivesOf{PSegment}
    segseq::SegmentSequence
    len::Int

    function PSegmentsOfSegmentSequence(segseq::SegmentSequence)
        N = length(segseq.values)
        if N < 2 return new(segseq, 0) end
        
        segments = N - 1
        break_every = segseq.break_every
        
        if break_every < 2 return new(segseq, segments) end
        
        return new(segseq, segments - div(segments, break_every))
    end
end

PrimitivesOf(self::SegmentSequence) = PSegmentsOfSegmentSequence(self)

function Base.length(self::PSegmentsOfSegmentSequence)::Int
    return self.len
end

function Base.getindex(self::PSegmentsOfSegmentSequence, index::Int)::PSegment
    @boundscheck 1 <= index <= length(self) || throw(BoundsError(self, index))

    if self.segseq.break_every < 2
        i = index
    else
        i = index + div(index - 1, self.segseq.break_every - 1)
    end
    
    return PSegment(self.segseq.values[i], self.segseq.values[i + 1])
end

function Base.iterate(self::PSegmentsOfSegmentSequence, index::Int = 1)
    if index > length(self)
        return nothing
    end
    return (self[index], index + 1)
end

Base.IteratorSize(::Type{<:PSegmentsOfSegmentSequence}) = Base.HasLength()
Base.eltype(::Type{PSegmentsOfSegmentSequence}) = PSegment

function custom_interleaver(vec, insert_val::T, n) where T
    new_len = length(vec) + div(length(vec), n)
    dest = Vector{T}(undef, new_len)
    
    dest_idx = 1
    for (i,e) in enumerate(vec)
        dest[dest_idx] = e
        dest_idx += 1
        if i % n == 0
            dest[dest_idx] = insert_val
            dest_idx += 1
        end
    end
    return dest
end

function render_node(segseq::SegmentSequence, data::SegmentSequenceDrawData, renderers::Dict{DataType,Renderer}, id::UInt32)::SegmentSequenceDrawData
    line_renderer::LineRenderer = renderers[LineRenderer]
    if data.handle == 0
        handle = if data.break_every >= 2
            add_dynamic!(line_renderer,
                collect(custom_interleaver((Vec3F(coord) for coord in segseq.values), Vec3FNan, data.break_every)),
                custom_interleaver(collect(Iterators.take(Iterators.cycle(data.colors), length(segseq.values))), zero(UInt32), data.break_every),
                custom_interleaver(collect(Iterators.take(Iterators.cycle((id,)), length(segseq.values))), zero(UInt32), data.break_every),
                data.size,
                data.style
            )
        else
            add_dynamic!(line_renderer,
                (Vec3F(coord) for coord in segseq.values),
                Iterators.cycle(data.colors),
                Iterators.cycle((id,)),
                data.size,
                data.style
            )
        end
        return SegmentSequenceDrawData(handle, data.colors, data.break_every, data.size, data.style)
    else
        if data.break_every >= 2
            update_dynamic!(line_renderer, data.handle,
                collect(custom_interleaver((Vec3F(coord) for coord in segseq.values), Vec3FNan, data.break_every)),
                custom_interleaver(collect(Iterators.take(Iterators.cycle(data.colors), length(segseq.values))), zero(UInt32), data.break_every),
                custom_interleaver(collect(Iterators.take(Iterators.cycle((id,)), length(segseq.values))), zero(UInt32), data.break_every),
                data.size,
                data.style
            )
        else
            update_dynamic!(line_renderer, data.handle,
                collect((Vec3F(coord) for coord in segseq.values)),
                Iterators.cycle(data.colors),
                Iterators.cycle((id,)),
                data.size,
                data.style
            )
        end
        return data
    end
end

function SegmentSequence(callback::Function, parents::Union{Vector{NodeHandle},Nothing}=nothing, break_every=2, color_style::Union{Nothing,String}=nothing;
    color="c", style="-", size=5.0f0)::NodeHandle
    (c, s) = parse_line_colors_style(color_style, color, style)
    draw_data = SegmentSequenceDrawData(UInt32(0), c, round(Int32, break_every), Float32(size), s)
    return add_node!(callback, SegmentSequence(); draw_data=draw_data, parents=parents)
end

# YELLOW Thread
SegmentSequence(parents::Vector{NodeHandle},break_every=2,color_style::Union{Nothing,String}=nothing;
    color="c",style="-",size=5.0f0)::NodeHandle =
SegmentSequence(_deps_collect, parents, break_every, color_style, color=color, style=style, size=size)

# YELLOW Thread
macro SegmentSequence(callback::Expr,break_every=2,args...)
    (positional_args, kw_args) = _parse_macro_arguments((:color_style,),(:color, :style, :size), args...)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.SegmentSequence,
                                positional_args, kw_args)
end


export SegmentSequence
export @SegmentSequence