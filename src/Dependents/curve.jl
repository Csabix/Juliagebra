
# ? ---------------------------------
# ! ParametricCurveDependent
# ? ---------------------------------

mutable struct ParametricCurveDependent <: RenderedDependentDNA
    _renderedDependent::RenderedDependent
    
    _range::AbstractRange{Float64}
    _colors::Vector{Vec3F}
    _width::Float32
    _type::UInt8
    _reversed::UInt8

    _tValues::Vector{Vec3D} # ? Calculated value for each t

    # YELLOW Thread
    function ParametricCurveDependent(
        callback::Function,dependents::Vector{<:DependentDNA},
        range::AbstractRange{Float64},
        colors::Vector{<:Tuple{Real,Real,Real}},
        type::UInt8,reversed::UInt8,width::Real
        )

        color = [Vec3F(c[1],c[2],c[3]) for c in colors]
        rd = RenderedDependent(callback,dependents)
        tValues = Vector{Vec3D}(undef,length(range))
        new(rd,range,color,width,type,reversed,tValues)
    end

    # YELLOW Thread
    function ParametricCurveDependent(
        callback::Function,dependents::Vector{<:DependentDNA},
        range::AbstractRange{Float64},
        color::Tuple{Real,Real,Real},
        type::UInt8,reversed::UInt8,width::Real
        )

        rd = RenderedDependent(callback,dependents)
        tValues = Vector{Vec3D}(undef,length(range))
        new(rd,range,[color],width,type,reversed,tValues)
    end
end

Base.string(self::ParametricCurveDependent)::String =  return "ParametricCurve: $(length(self._range))"
_RenderedDependent_(self::ParametricCurveDependent)::RenderedDependent = return self._renderedDependent

# YELLOW Thread
# RED Thread
function onNodeEval(self::ParametricCurveDependent)
    for index in 1:length(self._range)
        evalCallbackDp(self; callbackParams = self._range[index], returnParams = (index))
    end
end

evalCallbackDpReturn(self::ParametricCurveDependent,v,index)          = ((x,y,z) = v ; self._tValues[index] = Vec3D(x,y,z))
evalCallbackDpReturn(self::ParametricCurveDependent,v::Vec3D,index)   = self._tValues[index] = v
evalCallbackDpReturn(self::ParametricCurveDependent,v::Vec3F,index)   = self._tValues[index] = Vec3D(v)
evalCallbackDpReturn(self::ParametricCurveDependent,v::Nothing,index) = self._tValues[index] = Vec3DNan

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
    _refs::Vector{UInt32}

    # GREEN Thread
    function Curves(context::OpenGLData)
        renderer = Renderer{ParametricCurveDependent}(context)
        refs = Vector{UInt32}()
        new(renderer, refs)
    end
end

_Renderer_(self::Curves) = return self._renderer
Base.string(self::Curves) = return "Curves[$(length(self._coords))]"

# GREEN Thread
function added!(self::Curves,curve::ParametricCurveDependent)
    aID = UInt32(getGraphID(curve) + ID_LOWER_BOUND)
    push!(self._refs,
        add!(Val{:Line}(),
            curve._tValues,
            fill(curve._colors[1],length(curve._tValues)),
            fill(aID,length(curve._tValues)),
            curve._width,
            curve._type,
            curve._reversed != 0
        )
    )
end

# GREEN Thread
function sync!(self::Curves,curve::ParametricCurveDependent)
    ref = self._refs[getObserverID(curve)]
    update_coords!(Val{:Line}(),ref,curve._tValues,curve._width)
end

# GREEN Thread
function destroy!(self::Curves) end

# YELLOW Thread
Dependent2Observer(app::AppDNA,::ParametricCurveDependent) = getOpenGL(app)._renderers[_CURVES]

# YELLOW Thread
"""
    ParametricCurve(callback, range, [dependents]; kwargs...) -> ParametricCurvePlan

Construct a plan for a parametric curve defined by a generator function over a specific interval.

# Arguments
- `callback::Function`: A function (typically `t,dependents... -> Point`) that defines the curve's path.
- `range::AbstractRange{Float64}`: The interval and step size over which the `callback` is evaluated.
- `dependents::DependentsT`: A collection of `PlanDNA` objects that this curve depends on. Defaults to an empty vector.

# Keyword Arguments
- `color=(0.6, 0.6, 0.9)`: The RGB tuple or array of tuples defining the curve's color.
- `width=5.0f0`: The line thickness.
- `type=SOLID`: The visual style of the curve (e.g., solid, dashed).
- `reversed=false`: Whether to flip the line pattern.

# Returns
- `ParametricCurvePlan`: A `PlanDNA` for further use in dependencies.

# Example
App();

curve = ParametricCurve(t -> (cos(t), sin(t), 0.0), 0:0.1:2π; color=(1, 0, 0));

play!();
"""
ParametricCurve(callback::Function,range::AbstractRange{Float64},dependents::Vector{<:DependentDNA}=Vector{DependentDNA}();
                color=(0.6,0.6,0.9),width=5.0f0,type=SOLID,reversed=false)::ParametricCurveDependent =
return build!(ParametricCurveDependent(callback,dependents,range,color,type,reversed ? 0x1 : 0x0,width))

macro ParametricCurve(callback::Expr,range,kw_args...)
    parsed_kw_args = _parse_macro_kw_args([:color, :width, :type, :reversed], kw_args...)
    callback = _validate_callback_expr(callback, 1)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.ParametricCurve, (cb, deps) -> (cb, range, deps); parsed_kw_args...)
end

export ParametricCurve
export @ParametricCurve