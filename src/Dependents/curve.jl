
# ? ---------------------------------
# ! ParametricCurveDependent
# ? ---------------------------------

mutable struct ParametricCurveDependent <: RenderedDependentDNA
    _renderedDependent::RenderedDependent
    
    _range::AbstractRange{Float64}
    _colors::Vector{UInt32}
    _size::Float32
    _style::UInt8

    _tValues::Vector{Vec3D} # ? Calculated value for each t

    # YELLOW Thread
    function ParametricCurveDependent(
        callback::Function,dependents::Vector{<:DependentDNA},
        range::AbstractRange{Float64},
        color::Vector{UInt32},style::UInt8,size::Float32)
        dependent = RenderedDependent(callback,dependents)
        tValues = Vector{Vec3D}(undef,length(range))
        new(dependent,range,color,size,style,tValues)
    end
end

Base.string(self::ParametricCurveDependent)::String =  return "ParametricCurve: $(length(self._range))"
_RenderedDependent_(self::ParametricCurveDependent)::RenderedDependent = return self._renderedDependent

Base.eltype(dependent::ParametricCurveDependent)::DataType = Vector{Vec3D}

# YELLOW Thread
# RED Thread
function onNodeEval(self::ParametricCurveDependent)
    for index in 1:length(self._range)
        evalCallbackDp(self; callbackParams = self._range[index], returnParams = (index))
    end
end

function evalCallbackDpReturn(self::ParametricCurveDependent,v,index)
    if length(v) == 3
        self._tValues[index] = Vec3D(v[1],v[2],v[3])
    else
        self._tValues[index] = Vec3D(v[1],v[2],0.0)
    end
end
evalCallbackDpReturn(self::ParametricCurveDependent,v::Tuple{Any,Any},index)     = self._tValues[index] = Vec3D(v[1],v[2],0.0)
evalCallbackDpReturn(self::ParametricCurveDependent,v::Tuple{Any,Any,Any},index) = self._tValues[index] = Vec3D(v[1],v[2],v[3])
evalCallbackDpReturn(self::ParametricCurveDependent,v::Vec3D,index)              = self._tValues[index] = v
evalCallbackDpReturn(self::ParametricCurveDependent,v::Vec3F,index)              = self._tValues[index] = Vec3D(v)
evalCallbackDpReturn(self::ParametricCurveDependent,v::Vec2D,index)              = self._tValues[index] = Vec3D(v[1],v[2],0.0)
evalCallbackDpReturn(self::ParametricCurveDependent,v::Vec2F,index)              = self._tValues[index] = Vec3D(v[1],v[2],0.0)
evalCallbackDpReturn(self::ParametricCurveDependent,v::Nothing,index)            = self._tValues[index] = Vec3DNan

# ? For Intersectable ParametricCurves.

struct PSegmentsOfCurve <: PrimitivesOf{PSegment}
    _curve::ParametricCurveDependent
end
PrimitivesOf(self::ParametricCurveDependent) = return PSegmentsOfCurve(self)

Base.length(self::PSegmentsOfCurve) = (max(length(self._curve._range) - 1,0))

function Base.getindex(self::PSegmentsOfCurve, index::Integer)::Union{Nothing, PSegment}
    if ((1 <= index) && (index <= length(self)))
        return PSegment(self._curve._tValues[index], self._curve._tValues[index + 1])
    else
        return nothing 
    end
end

function Base.iterate(self::PSegmentsOfCurve, index::Integer = 1)
    if ((1 <= index) && (index <= length(self)))
        return (self[index], (index + 1))
    else
        return nothing
    end
end


# ? ---------------------------------
# ! Curves
# ? ---------------------------------

mutable struct Curves <: RendererDNA{ParametricCurveDependent}
    _renderer::Renderer{ParametricCurveDependent}
    _renderers::PrimitiveRenderers
    _refs::Vector{UInt32}

    # GREEN Thread
    function Curves(context::OpenGLData)
        renderer = Renderer{ParametricCurveDependent}(context)
        refs = Vector{UInt32}()
        new(renderer, context._renderers, refs)
    end
end

_Renderer_(self::Curves) = return self._renderer
Base.string(self::Curves) = return "Curves[$(length(self._coords))]"

# GREEN Thread
function added!(self::Curves,curve::ParametricCurveDependent)
    aID = UInt32(getGraphID(curve) + ID_LOWER_BOUND)
    push!(self._refs,
        add!(self._renderers.line,
            curve._tValues,
            cycle(curve._colors),
            cycle(aID),
            curve._size,
            curve._style,
        )
    )
end

# GREEN Thread
function sync!(self::Curves,curve::ParametricCurveDependent)
    ref = self._refs[getObserverID(curve)]
    update_coords!(self._renderers.line,ref,curve._tValues)
end

# GREEN Thread
function destroy!(self::Curves) end

# YELLOW Thread
Dependent2Observer(app::AppDNA,::ParametricCurveDependent) = getDependentObservers(app)[_CURVES]

# YELLOW Thread
function ParametricCurve(callback::Function,range::AbstractRange{Float64},
                dependents::Vector{<:DependentDNA}=DependentDNA[],color_style::Union{Nothing,String}=nothing;
                color="c",style="-",size=5.0f0)::ParametricCurveDependent
    (c,s) = parse_line_colors_style(color_style,color,style)
    return build!(ParametricCurveDependent(callback,dependents,range,c,s,Float32(size)))
end

macro ParametricCurve(callback::Expr,range,args...)
    (positional_args, kw_args) = _parse_macro_arguments((:color_style,),(:color, :style, :size), args...)
    callback = _validate_callback_expr(callback, 1)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.ParametricCurve,
                                positional_args, kw_args, (cb, deps) -> (cb, range, deps))
end

export ParametricCurve
export @ParametricCurve
