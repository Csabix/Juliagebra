mutable struct PointSetDependent <:RenderedDependentDNA
    _renderedDependent::RenderedDependent
    _coords::Vector{Vec3D}
    _color::UInt32
    _style::UInt8
    _size::UInt8

    # YELLOW Thread
    function PointSetDependent(callback::Function,dependents::Vector{<:DependentDNA},
                               color::UInt32,style::UInt8,size::UInt8)
        dependent = RenderedDependent(callback,dependents)
        coords = Vector{Vec3D}()
        new(dependent,coords,color,style,size)
    end
end

_RenderedDependent_(self::PointSetDependent)::RenderedDependent = return self._renderedDependent
Base.string(self::PointSetDependent) = "PointSetDependent[$(_Dependent_(self)._graphID) - $(string(length(_Dependent_(self)._graphParents))) - $(string(length(_Dependent_(self)._graphChain)))]"

# YELLOW Thread
# RED Thread
onNodeEval(self::PointSetDependent) = evalCallbackDp(self)

Base.eltype(dependent::PointSetDependent)::DataType = Vector{Vec3D}
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
    _refs::Vector{PointHandle}

    # GREEN Thread
    function PointSets(context::OpenGLData) 
        renderer = Renderer{PointSetDependent}(context)
        refs = Vector{PointHandle}()
        new(renderer,context._renderers,refs)
    end
end

_Renderer_(self::PointSets) = return self._renderer
Base.string(self::PointSets) = return "PointSets($(length(self._buffers)))"

# GREEN Thread
function added!(self::PointSets,point_set::PointSetDependent)
    aID = UInt32(getGraphID(point_set) + ID_LOWER_BOUND)
    ref = add!(self._renderers.point,
        (Vec3F(coord) for coord in point_set._coords),
        [point_set._color],
        [point_set._style],
        [UInt8(point_set._size)],
        [aID])
    push!(self._refs, ref)
end

function sync!(self::PointSets,point_set::PointSetDependent)
    ref = self._refs[getObserverID(point_set)]
    set_position!(self._renderers.point,ref,point_set._coords)
end

function destroy!(self::PointSets) end

# YELLOW Thread
Dependent2Observer(app::AppDNA,::PointSetDependent)::PointSets = getDependentObservers(app)[_POINT_SETS]

function PointSet(callback::Function,dependents::Vector{<:DependentDNA}=DependentDNA[],color_style::Union{Nothing,String}=nothing;
    color="m",style=".",size=25)::PointSetDependent
    (c,s) = parse_point_color_style(color_style,color,style)
    Build!(PointSetDependent(callback,dependents,c,s,round(UInt8,size)))
end

PointSet(dependents::Vector{<:DependentDNA},color_style::Union{Nothing,String}=nothing;
    color="m",style=".",size=25)::PointSetDependent =
PointSet(_deps_collect,dependents,color_style;color=color,style=style,size=size)

PointSet(positions,color_style::Union{Nothing,String}=nothing;
    color="m",style=".",size=25) =
GenericValueHolder(_deps_collect,Vector{Vec3D},[Point(p[1],p[2],p[3],color_style;color=color,style=style,size=size) for p in positions])

macro PointSet(callback::Expr, args...)
    (positional_args, kw_args) = _parse_macro_arguments((:color_style,),(:color, :style, :size), args...)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.PointSet,
                                positional_args, kw_args)
end

export PointSet
export @PointSet