mutable struct SegmentSequence
    values::Vector{Vec3D}

    function SegmentSequence()
        new(Vector{Vec3D}())
    end
end

struct SegmentSequenceDrawData
    handle::LineHandle
    colors::Vector{UInt32}
    break_every::Int32
    size::Float32
    style::UInt8
end

function get_property_hint(::SegmentSequenceDrawData, s::Symbol)::Union{PropertyHint, Nothing}
    if s== :colors
        return PropertyHintColor()
    elseif s==:style
        return PropertyHintSlider(1,_LINE_STYLE_COUNT)
    elseif s == :size
        return PropertyHintSlider(0,10)
    else
        return nothing
    end
end

function rerender_node(data::SegmentSequenceDrawData, r::Dict{DataType, Renderer})
    line_renderer::LineRenderer = r[LineRenderer]::LineRenderer
    update_colors!(line_renderer, data.handle, data.colors)
    update_size!(line_renderer, data.handle, data.size)
    update_style!(line_renderer, data.handle, data.style)
end

function reconstruct_node(data::SegmentSequenceDrawData, p::Dict{Symbol, Any})::SegmentSequenceDrawData
    return SegmentSequenceDrawData(
        data.handle,
        get(p, :colors, data.colors),
        get(p, :break_every, data.break_every),
        get(p, :size, data.size),
        get(p, :style, data.style)
    )
end

function convert_callback_result(s::SegmentSequence,coords)
    Base.resize!(s.values,length(coords))
    index = 1
    for coord in coords
        @inbounds s.values[index] = Vec3D(coord...)
        index += 1
    end
    return s
end
convert_callback_result(s::SegmentSequence,::Nothing) = (empty!(s.values);s)

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

struct _NanInterleaver
    vec::Vector{Vec3D}
    n::Int32
end

Base.eltype(::Type{_NanInterleaver}) = Vec3F
Base.length(it::_NanInterleaver) = length(it.vec) + div(length(it.vec), it.n)

function Base.iterate(it::_NanInterleaver, state=(1, false))
    i, inserting = state
    
    if inserting
        return (Vec3FNan, (i + 1, false))
    else
        i > length(it.vec) && return nothing

        @inbounds val = Vec3F(it.vec[i])
        if i % it.n == 0
            return (val, (i, true))
        else
            return (val, (i + 1, false))
        end
    end
end

function render_node(segseq::SegmentSequence, data::SegmentSequenceDrawData, renderers::Dict{DataType,Renderer}, id::UInt32)::SegmentSequenceDrawData
    line_renderer::LineRenderer = renderers[LineRenderer]
    if is_null(data.handle)
        handle = if data.break_every >= 2
            add!(line_renderer,
                _NanInterleaver(segseq.values, data.break_every),
                data.colors,
                (id,),
                data.style,
                data.size
            )
        else
            add!(line_renderer,
                (Vec3F(coord) for coord in segseq.values),
                data.colors,
                (id,),
                data.style,
                data.size
            )
        end
        return SegmentSequenceDrawData(handle, data.colors, data.break_every, data.size, data.style)
    else
        if data.break_every >= 2
            @inbounds update_coords!(line_renderer, data.handle,
                _NanInterleaver(segseq.values, data.break_every))
        else
            @inbounds update_coords!(line_renderer, data.handle,segseq.values)
        end
        return data
    end
end

function SegmentSequence(callback::Function, parents::Union{Vector{NodeHandle},Nothing}=nothing, break_every=2, color_style::Union{Nothing,String}=nothing;
    color="c", style="-", size=5.0f0)::NodeHandle
    (c, s) = parse_line_colors_style(color_style, color, style)
    draw_data = SegmentSequenceDrawData(LineHandle(), c, round(Int32, break_every), Float32(size), s)
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