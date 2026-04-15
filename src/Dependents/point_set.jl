mutable struct PointSetDependent <:RenderedDependentDNA
    _renderedDependent::RenderedDependent
    _coords::Vector{Vec3D}
    _color::Vec3F
    _width::Float32

    # YELLOW Thread
    function PointSetDependent(callback::Function,dependents::Vector{<:DependentDNA},color::Tuple{Real,Real,Real},width::Real)
        dependent = RenderedDependent(callback,dependents)
        coords = Vector{Vec3D}()

        new(dependent,coords,color,width)
    end
end

_RenderedDependent_(self::PointSetDependent)::RenderedDependent = return self._renderedDependent
Base.string(self::PointSetDependent) = "PointSetDependent[$(_Dependent_(self)._graphID) - $(string(length(_Dependent_(self)._graphParents))) - $(string(length(_Dependent_(self)._graphChain)))]"

# YELLOW Thread
# RED Thread
onNodeEval(self::PointSetDependent) = evalCallbackDp(self)

evalCallbackDpEntry(self::PointSetDependent)::Vector{Vec3D} = self._coords

function evalCallbackDpReturn(self::PointSetDependent,coords::Vector{Vec3D})
    @assert length(self._coords) == length(coords) || length(self._coords) == 0
    self._coords = coords
end
evalCallbackDpReturn(self::PointSetDependent,coords::Vector{Vec3F})  = evalCallbackDpReturn(self,Vec3D.(coords))
evalCallbackDpReturn(self::PointSetDependent,coords::Vector{<:Tuple})  = evalCallbackDpReturn(self,[Vec3D(coord...) for coord in coords])
evalCallbackDpReturn(self::PointSetDependent,coords::Vector{<:Vector}) = evalCallbackDpReturn(self,[Vec3D(coord...) for coord in coords])
evalCallbackDpReturn(self::PointSetDependent,::Nothing) = fill!(self._coords, Vec3DNan)

mutable struct PointSets <:RendererDNA{PointSetDependent}
    _renderer::Renderer{PointSetDependent}
    _renderers::PrimitiveRenderers
    _refs::Vector{UInt32}

    # GREEN Thread
    function PointSets(context::OpenGLData) 
        renderer = Renderer{PointSetDependent}(context)
        refs = Vector{UInt32}()
        new(renderer,context._renderers,refs)
    end
end

_Renderer_(self::PointSets) = return self._renderer
Base.string(self::PointSets) = return "PointSets($(length(self._buffers)))"

# GREEN Thread
function added!(self::PointSets,point_set::PointSetDependent)
    aID = UInt32(getGraphID(point_set) + ID_LOWER_BOUND)
    push!(self._refs,
        add!(self._renderers.point,
               (Vec3F(coord) for coord in point_set._coords),
               cycle([POINT_NONE]),
               cycle([point_set._color]),
               cycle([UInt8(point_set._width)]),
               cycle([aID]))::UInt32
    )
end

function sync!(self::PointSets,point_set::PointSetDependent)
    ref = self._refs[getObserverID(point_set)]
    view = update_coords!(self._renderers.point,ref,UInt32(length(point_set._coords)))
    for (i, coord) in enumerate(point_set._coords)
        view[i] = Vec3F(coord)
    end
end

function destroy!(self::PointSets) end

# YELLOW Thread
Dependent2Observer(app::AppDNA,::PointSetDependent)::PointSets = getDependentObservers(app)[_POINT_SETS]

PointSet(callback::Function,dependents::Vector{<:DependentDNA}=Vector{DependentDNA}();color=(0.0,1.0,1.0),width=25.0f0)::PointSetDependent =
build!(PointSetDependent(callback,dependents,color,width))

PointSet(dependents::Vector{<:DependentDNA};color=(0.0,1.0,1.0),width=25.0f0)::PointSetDependent =
PointSet(_deps_collect,dependents;color=color,width=width)

PointSet(positions) =
GenericValueHolder(_deps_collect,Vector{Vec3D},[Point(p...) for p in positions])

macro PointSet(callback::Expr, kw_args...)
    parsed_kw_args = _parse_macro_kw_args([:color, :width], kw_args...)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.PointSet; parsed_kw_args...)
end

export PointSet
export @PointSet