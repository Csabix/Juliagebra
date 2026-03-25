
# ? ---------------------------------
# ! SegmentSequenceDependent
# ? ---------------------------------

mutable struct SegmentSequenceDependent <: RenderedDependentDNA
    _renderedDependent::RenderedDependent
    
    _colors::Vector{Vec3F}
    _break_every::Int32
    _width::Float32
    _type::UInt8
    _reversed::UInt8

    _values::Vector{Vec3D}

    # YELLOW Thread
    function SegmentSequenceDependent(
        callback::Function,dependents::Vector{<:DependentDNA},
        colors::Vector{Vec3F},break_every::Real,
        type::UInt8,reversed::UInt8,width::Real)
        
        dependent = RenderedDependent(callback,dependents)
        values = Vector{Vec3F}()

        new(dependent,colors,break_every,width,type,reversed,values)
    end
end

Base.string(self::SegmentSequenceDependent)::String =  return "Segment sequence: $(length(self._values))"
_RenderedDependent_(self::SegmentSequenceDependent)::RenderedDependent = return self._renderedDependent

# YELLOW Thread
# RED Thread
onNodeEval(self::SegmentSequenceDependent) = evalCallbackDp(self)

evalCallbackDpReturn(self::SegmentSequenceDependent,coords::Vector{Vec3D})  = self._values = coords
evalCallbackDpReturn(self::SegmentSequenceDependent,coords::Vector{Vec3F})  = self._values = [Vec3D(coord...) for coord in coords]
evalCallbackDpReturn(self::SegmentSequenceDependent,coords::Vector{Tuple})  = self._values = [Vec3D(coord...) for coord in coords]
evalCallbackDpReturn(self::SegmentSequenceDependent,coords::Vector{Vector}) = self._values = [Vec3D(coord...) for coord in coords]
evalCallbackDpReturn(self::SegmentSequenceDependent,::Nothing) = self.values = Vec3D[]

struct PSegmentsOfSegmentSequence <: PrimitivesOf{PSegment}
    _segseq::SegmentSequenceDependent
end
PrimitivesOf(self::SegmentSequenceDependent) = return PSegmentsOfSegmentSequence(self)

function Base.length(self::PSegmentsOfSegmentSequence)
    len = 0
    values = self._segseq._values
    for i in 1:length(values)-1
        if !(any(isnan,values[i]) || any(isnan,values[i+1]))
            len += 1
        end
    end
    return len
end

# SLOOW O(N)
function Base.getindex(self::PSegmentsOfSegmentSequence, index::Integer)::Union{Nothing, PSegment}
    if index < 1 return nothing end

    values = self._segseq._values
    n = length(values)
    i = 1

    while i < n
        if !(any(isnan,values[i]) || any(isnan,values[i+1]))
            index -= 1
            if index == 0 break end
        end
        i += 1
    end

    if index == 0
        return PSegment(values[i], values[i + 1])
    else
        return nothing
    end
end

function Base.iterate(self::PSegmentsOfSegmentSequence, index::Integer = 1)
    if index < 1 return nothing end

    values = self._segseq._values
    n = length(values)

    while index < n && (any(isnan,values[index]) || any(isnan,values[index + 1]))
        index += 1
    end

    if index == n return nothing
    else return (PSegment(values[index], values[index + 1]),index + 1) end
end

# ? ---------------------------------
# ! SegmentSequenceRenderer
# ? ---------------------------------

mutable struct SegmentSequenceRenderer <: RendererDNA{SegmentSequenceDependent}
    _renderer::Renderer{SegmentSequenceDependent}
    _indexes::Vector{UInt32}
    # GREEN Thread
    function SegmentSequenceRenderer(context::OpenGLData)
        renderer = Renderer{SegmentSequenceDependent}(context)
        indexes = Vector{UInt32}()
        return new(renderer, indexes)
    end
end

_Renderer_(self::SegmentSequenceRenderer) = return self._renderer
Base.string(self::SegmentSequenceRenderer) = return "SegmentSequenceRenderer[$(length(self._coords))]"

function nan_interleaver(vec::Vector{Vec3D},N)
    return (Vec3F(val) for (i, x) in enumerate(vec) for val in (i % N == 0 ? (x, Vec3FNan) : (x,)))
end

# GREEN Thread
function added!(self::SegmentSequenceRenderer,segseq::SegmentSequenceDependent)
    aID = UInt32(getGraphID(segseq) + ID_LOWER_BOUND)
    push!(self._indexes,
        add_dynamic!(Val{:Line}(),
            collect(nan_interleaver(segseq._values,segseq._break_every)),
            Iterators.cycle(segseq._colors),
            Iterators.cycle([aID]),
            segseq._width,
            segseq._type,
            segseq._reversed != 0
        )
    )
end

# GREEN Thread
function sync!(self::SegmentSequenceRenderer,segseq::SegmentSequenceDependent)
    aID = UInt32(getGraphID(segseq) + ID_LOWER_BOUND)
    index = self._indexes[getObserverID(segseq)]
    update_dynamic!(Val{:Line}(),index,
        collect(nan_interleaver(segseq._values)),
        Iterators.cycle(segseq._colors),
        Iterators.cycle([aID]),
        segseq._width,
        segseq._type,
        segseq._reversed != 0
    )
end


function destroy!(self::SegmentSequenceRenderer)
end

# YELLOW Thread
Dependent2Observer(app::AppDNA,::SegmentSequenceDependent)::SegmentSequenceRenderer = getOpenGL(app)._renderers[_SEGMENTS]

# ? ---------------------------------
# ! SegmentSequence
# ? ---------------------------------

_Colors(c::Tuple{Real,Real,Real})::Vector{Vec3F} = Vector{Vec3F}([Vec3F(c...)])
_Colors(c::Vector)::Vector{Vec3F} = Vector{Vec3F}([Vec3F(cc...) for cc in c])


# YELLOW Thread
function SegmentSequence(callback::Function,dependents=Vector{DependentDNA}(),break_every=2;
                color=(0.6,0.6,0.9),width=5.0f0,type=SOLID,reversed=false)::SegmentSequenceDependent
    
    colors::Vector{Vec3F} = _Colors(color)
    
    return build!(SegmentSequenceDependent(callback, dependents, colors, break_every, type, reversed ? 0x1 : 0x0, width))
end

# YELLOW Thread
function SegmentSequence(dependents=Vector{DependentDNA}(),break_every=2;
                color=(0.6,0.6,0.9),width=5.0f0,type=SOLID,reversed=false)::SegmentSequenceDependent
    
    colors::Vector{Vec3F} = _Colors(color)

    return build!(SegmentSequenceDependent(_deps_collect, dependents, colors, break_every, type, reversed ? 0x1 : 0x0, width))
end

# YELLOW Thread
macro SegmentSequence(callback::Expr,break_every=2,kw_args...)
    (break_every, kw_args) = _kw_arg_or_default(break_every, 2, kw_args)

    parsed_kw_args = _parse_macro_kw_args([:color, :width, :type, :reversed], kw_args...)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.SegmentSequence, (cb, deps) -> (cb, deps, break_every); parsed_kw_args...)
end


export SegmentSequence
export @SegmentSequence