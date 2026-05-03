
# ? ---------------------------------
# ! SegmentSequenceDependent
# ? ---------------------------------

mutable struct SegmentSequenceDependent <: RenderedDependentDNA
    _renderedDependent::RenderedDependent
    
    _colors::Vector{UInt32}
    _break_every::Int32
    _size::Float32
    _style::UInt8

    _values::Vector{Vec3D}

    # YELLOW Thread
    function SegmentSequenceDependent(
        callback::Function,dependents::Vector{<:DependentDNA},
        break_every::Int32,
        color::Vector{UInt32},style::UInt8,size::Float32)
        dependent = RenderedDependent(callback,dependents)
        values = Vector{Vec3F}()
        new(dependent,color,break_every,size,style,values)
    end
end

Base.string(self::SegmentSequenceDependent)::String =  return "Segment sequence: $(length(self._values))"
_RenderedDependent_(self::SegmentSequenceDependent)::RenderedDependent = return self._renderedDependent

# YELLOW Thread
# RED Thread
onNodeEval(self::SegmentSequenceDependent) = evalCallbackDp(self)

Base.eltype(dependent::SegmentSequenceDependent)::DataType = Vector{Vec3D}

evalCallbackDpReturn(self::SegmentSequenceDependent,coords::Vector{Vec3D})  = self._values = coords
evalCallbackDpReturn(self::SegmentSequenceDependent,coords::Vector{Vec3F})  = self._values = [Vec3D(coord...) for coord in coords]
evalCallbackDpReturn(self::SegmentSequenceDependent,coords::Vector{Tuple})  = self._values = [Vec3D(coord...) for coord in coords]
evalCallbackDpReturn(self::SegmentSequenceDependent,coords::Vector{Vector}) = self._values = [Vec3D(coord...) for coord in coords]
evalCallbackDpReturn(self::SegmentSequenceDependent,::Nothing) = self.values = Vec3D[]

struct PSegmentsOfSegmentSequence <: PrimitivesOf{PSegment}
    _segseq::SegmentSequenceDependent
    len::Int

    function PSegmentsOfSegmentSequence(segseq::SegmentSequenceDependent)
        N = length(segseq._values)
        if N < 2 return new(segseq, 0) end
        
        segments = N - 1
        break_every = segseq._break_every
        
        if break_every < 2 return new(segseq, segments) end
        
        return new(segseq, segments - div(segments, break_every))
    end
end

PrimitivesOf(self::SegmentSequenceDependent) = PSegmentsOfSegmentSequence(self)

function Base.length(self::PSegmentsOfSegmentSequence)::Int
    return self.len
end

function Base.getindex(self::PSegmentsOfSegmentSequence, index::Int)::PSegment
    @boundscheck 1 <= index <= length(self) || throw(BoundsError(self, index))

    if self._segseq._break_every < 2
        i = index
    else
        i = index + div(index - 1, self._segseq._break_every - 1)
    end
    
    return PSegment(self._segseq._values[i], self._segseq._values[i + 1])
end

function Base.iterate(self::PSegmentsOfSegmentSequence, index::Int = 1)
    if index > length(self)
        return nothing
    end
    return (self[index], index + 1)
end

Base.IteratorSize(::Type{<:PSegmentsOfSegmentSequence}) = Base.HasLength()
Base.eltype(::Type{PSegmentsOfSegmentSequence}) = PSegment

# ? ---------------------------------
# ! SegmentSequences
# ? ---------------------------------

mutable struct SegmentSequences <: RendererDNA{SegmentSequenceDependent}
    _renderer::Renderer{SegmentSequenceDependent}
    _renderers::PrimitiveRenderers
    _refs::Vector{UInt32}
    # GREEN Thread
    function SegmentSequences(context::OpenGLData)
        renderer = Renderer{SegmentSequenceDependent}(context)
        refs = Vector{UInt32}()
        return new(renderer, context._renderers, refs)
    end
end

_Renderer_(self::SegmentSequences) = return self._renderer
Base.string(self::SegmentSequences) = return "SegmentSequences[$(length(self._coords))]"

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

# GREEN Thread
function added!(self::SegmentSequences,segseq::SegmentSequenceDependent)
    aID = UInt32(getGraphID(segseq) + ID_LOWER_BOUND)
    ref = if segseq._break_every >= 2
        add_dynamic!(self._renderers.line,
            collect(custom_interleaver((Vec3F(coord) for coord in segseq._values),Vec3FNan,segseq._break_every)),
            custom_interleaver(collect(Iterators.take(Iterators.cycle(segseq._colors),length(segseq._values))),zero(UInt32),segseq._break_every),
            custom_interleaver(collect(Iterators.take(Iterators.cycle((aID,)),length(segseq._values))),zero(UInt32),segseq._break_every),
            segseq._size,
            segseq._style
        )
    else
        add_dynamic!(self._renderers.line,
            (Vec3F(coord) for coord in segseq._values),
            Iterators.cycle(segseq._colors),
            Iterators.cycle((aID,)),
            segseq._size,
            segseq._style
        )
    end
    push!(self._refs, ref)
end

# GREEN Thread
function sync!(self::SegmentSequences,segseq::SegmentSequenceDependent)
    aID = UInt32(getGraphID(segseq) + ID_LOWER_BOUND)
    ref = self._refs[getObserverID(segseq)]
    if segseq._break_every >= 2
        update_dynamic!(self._renderers.line,ref,
            collect(custom_interleaver((Vec3F(coord) for coord in segseq._values),Vec3FNan,segseq._break_every)),
            custom_interleaver(collect(Iterators.take(Iterators.cycle(segseq._colors),length(segseq._values))),zero(UInt32),segseq._break_every),
            custom_interleaver(collect(Iterators.take(Iterators.cycle((aID,)),length(segseq._values))),zero(UInt32),segseq._break_every),
            segseq._size,
            segseq._style
        )
    else
        update_dynamic!(self._renderers.line,ref,
            collect((Vec3F(coord) for coord in segseq._values)),
            Iterators.cycle(segseq._colors),
            Iterators.cycle([aID]),
            segseq._size,
            segseq._style
        )
    end
end


function destroy!(self::SegmentSequences)
end

# YELLOW Thread
Dependent2Observer(app::AppDNA,::SegmentSequenceDependent)::SegmentSequences = getDependentObservers(app)[_SEGMENT_SEQUENCES]

# ? ---------------------------------
# ! SegmentSequence
# ? ---------------------------------

# YELLOW Thread
function SegmentSequence(callback::Function,dependents::Vector{<:DependentDNA}=DependentDNA[],break_every=2,color_style::Union{Nothing,String}=nothing;
    color="c",style="-",size=5.0f0)::SegmentSequenceDependent
    (c,s) = parse_line_colors_style(color_style, color, style)
    return build!(SegmentSequenceDependent(callback, dependents, break_every, c, s, size))
end

# YELLOW Thread
SegmentSequence(dependents::Vector{<:DependentDNA}=DependentDNA[],break_every=2,color_style::Union{Nothing,String}=nothing;
    color="c",style="-",size=5.0f0)::SegmentSequenceDependent =
SegmentSequence(_deps_collect, dependents, break_every, color_style, color=color, style=style, size=size)

# YELLOW Thread
macro SegmentSequence(callback::Expr,break_every=2,kw_args...)
    (positional_args, kw_args) = _parse_macro_arguments((:color_style,),(:color, :style, :size), args...)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.SegmentSequence,
                                positional_args, kw_args)
end


export SegmentSequence
export @SegmentSequence