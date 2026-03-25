mutable struct PointSequenceDependent <:RenderedDependentDNA
    _renderedDependent::RenderedDependent
    _coords::Vector{Vec3D}
    _color::Vec3F
    _width::Float32

    # YELLOW Thread
    function PointSequenceDependent(callback::Function,dependents::Vector{<:DependentDNA},color::Tuple{Real,Real,Real},width::Real)
        dependent = RenderedDependent(callback,dependents)
        coords = Vector{Vec3D}()

        new(dependent,coords,color,width)
    end
end

_RenderedDependent_(self::PointSequenceDependent)::RenderedDependent = return self._renderedDependent
Base.string(self::PointSequenceDependent) = "PointSequence[$(_Dependent_(self)._graphID) - $(string(length(_Dependent_(self)._graphParents))) - $(string(length(_Dependent_(self)._graphChain)))]"

# YELLOW Thread
# RED Thread
onNodeEval(self::PointSequenceDependent) = evalCallbackDp(self)

evalCallbackDpEntry(self::PointSequenceDependent)::Vector{Vec3D} = self._coords

evalCallbackDpReturn(self::PointSequenceDependent,coords::Vector{Vec3D})   = self._coords = coords
evalCallbackDpReturn(self::PointSequenceDependent,coords::Vector{Vec3F})   = self._coords = Vec3D.(coords)
evalCallbackDpReturn(self::PointSequenceDependent,coords::Vector{<:Tuple}) = self._coords = [Vec3D(coord...) for coord in coords]
evalCallbackDpReturn(self::PointSequenceDependent,coords::Vector{<:AbstractVector}) = self._coords = [Vec3D(coord...) for coord in coords]
evalCallbackDpReturn(self::PointSequenceDependent,::Nothing) = self._coords = Vec3D[]

mutable struct PointSequences <:RendererDNA{PointSequenceDependent}
    _renderer::Renderer{PointSequenceDependent}
    _refs::Vector{UInt32}

    # GREEN Thread
    function PointSequences(context::OpenGLData) 
        renderer = Renderer{PointSequenceDependent}(context)
        refs = Vector{UInt32}()
        new(renderer,refs)
    end
end

_Renderer_(self::PointSequences) = return self._renderer
Base.string(self::PointSequences) = return "PointSequences($(length(self._buffers)))"

# GREEN Thread
function added!(self::PointSequences,point_cloud::PointSequenceDependent)
    aID = UInt32(getGraphID(point_cloud) + ID_LOWER_BOUND)
    N = length(point_cloud._coords)
    ref = add_dynamic!(Val{:Point}(),
                       (Vec3F(coord) for coord in point_cloud._coords),
                       cycle([POINT_NONE]),
                       cycle([point_cloud._color]),
                       cycle([UInt8(point_cloud._width)]),
                       cycle([aID]))
    push!(self._refs, ref);
end

function sync!(self::PointSequences,point_cloud::PointSequenceDependent)
    aID = UInt32(getGraphID(point_cloud) + ID_LOWER_BOUND)
    index = self._refs[getObserverID(point_cloud)]
    update_dyncamic!(Val{:Point}(), index,
                    (Vec3F(coord) for coord in point_cloud._coords),
                    cycle([POINT_NONE]),
                    cycle([point_cloud._color]),
                    cycle([UInt8(point_cloud._width)]),
                    cycle([aID]))
end

function destroy!(self::PointSequences) end

# YELLOW Thread
Dependent2Observer(app::AppDNA,::PointSequenceDependent)::PointSequences = getOpenGL(app)._renderers[_POINT_SEQUENCES]

PointSequence(callback::Function,dependents::Vector{<:DependentDNA}=Vector{DependentDNA}();color=(0.0,1.0,1.0),width=25.0f0)::PointSequenceDependent =
build!(PointSequenceDependent(callback,dependents,color,width))

PointSequence(dependents::Vector{<:DependentDNA};color=(0.0,1.0,1.0),width=25.0f0)::PointSequenceDependent =
PointSequence(_deps_collect,dependents;color=color,width=width)

macro PointSequence(callback::Expr, kw_args...)
    parsed_kw_args = _parse_macro_kw_args([:color, :width], kw_args...)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.PointSequence; parsed_kw_args...)
end

export PointSequence
export @PointSequence