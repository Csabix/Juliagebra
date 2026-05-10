mutable struct PointSequenceDependent <:RenderedDependentDNA
    _renderedDependent::RenderedDependent
    _coords::Vector{Vec3D}
    _color::UInt32
    _style::UInt8
    _size::UInt8

    # YELLOW Thread
    function PointSequenceDependent(callback::Function,dependents::Vector{<:DependentDNA},
                                    color::UInt32,style::UInt8,size::UInt8)
        dependent = RenderedDependent(callback,dependents)
        coords = Vector{Vec3D}()
        new(dependent,coords,color,style,size)
    end
end

_RenderedDependent_(self::PointSequenceDependent)::RenderedDependent = return self._renderedDependent
Base.string(self::PointSequenceDependent) = "PointSequence[$(_Dependent_(self)._graphID) - $(string(length(_Dependent_(self)._graphParents))) - $(string(length(_Dependent_(self)._graphChain)))]"

# YELLOW Thread
# RED Thread
onNodeEval(self::PointSequenceDependent) = evalCallbackDp(self)

Base.eltype(dependent::PointSequenceDependent)::DataType = Vector{Vec3D}
evalCallbackDpEntry(self::PointSequenceDependent)::Vector{Vec3D} = self._coords

evalCallbackDpReturn(self::PointSequenceDependent,coords::Vector{Vec3D})   = self._coords = coords
evalCallbackDpReturn(self::PointSequenceDependent,coords::Vector{Vec3F})   = self._coords = Vec3D.(coords)
evalCallbackDpReturn(self::PointSequenceDependent,coords::Vector{<:Tuple}) = self._coords = [Vec3D(coord...) for coord in coords]
evalCallbackDpReturn(self::PointSequenceDependent,coords::Vector{<:AbstractVector}) = self._coords = [Vec3D(coord...) for coord in coords]
evalCallbackDpReturn(self::PointSequenceDependent,::Nothing) = self._coords = Vec3D[]

mutable struct PointSequences <:RendererDNA{PointSequenceDependent}
    _renderer::Renderer{PointSequenceDependent}
    _renderers::PrimitiveRenderers
    _refs::Vector{UInt32}

    # GREEN Thread
    function PointSequences(context::OpenGLData) 
        renderer = Renderer{PointSequenceDependent}(context)
        refs = Vector{UInt32}()
        new(renderer,context._renderers,refs)
    end
end

_Renderer_(self::PointSequences) = return self._renderer
Base.string(self::PointSequences) = return "PointSequences($(length(self._buffers)))"

# GREEN Thread
function added!(self::PointSequences,point_cloud::PointSequenceDependent)
    aID = UInt32(getGraphID(point_cloud) + ID_LOWER_BOUND)
    ref = add_dynamic!(self._renderers.point,
                       (Vec3F(coord) for coord in point_cloud._coords),
                       cycle([point_cloud._color]),
                       cycle([point_cloud._style]),
                       cycle([UInt8(point_cloud._size)]),
                       cycle([aID]))
    push!(self._refs, ref);
end

function sync!(self::PointSequences,point_cloud::PointSequenceDependent)
    aID = UInt32(getGraphID(point_cloud) + ID_LOWER_BOUND)
    ref = self._refs[getObserverID(point_cloud)]
    update_dyncamic!(self._renderers.point, ref,
                    (Vec3F(coord) for coord in point_cloud._coords),
                    cycle([point_cloud._color]),
                    cycle([point_cloud._style]),
                    cycle([UInt8(point_cloud._size)]),
                    cycle([aID]))
end

function destroy!(self::PointSequences) end

# YELLOW Thread
Dependent2Observer(app::AppDNA,::PointSequenceDependent)::PointSequences = getDependentObservers(app)[_POINT_SEQUENCES]

function PointSequence(callback::Function,dependents::Vector{<:DependentDNA}=DependentDNA[],color_style::Union{Nothing,String}=nothing;
    color="m",style=".",size=25)::PointSequenceDependent
    (c,s) = parse_point_color_style(color_style,color,style)
    Build!(PointSequenceDependent(callback,dependents,c,s,round(UInt8,size)))
end

PointSequence(dependents::Vector{<:DependentDNA},color_style::Union{Nothing,String}=nothing;
    color="m",style=".",size=25)::PointSequenceDependent =
PointSequence(_deps_collect,dependents,color_style;color=color,style=style,size=size)

macro PointSequence(callback::Expr, args...)
    (positional_args, kw_args) = _parse_macro_arguments((:color_style,),(:color, :style, :size), args...)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.PointSequence,
                                positional_args, kw_args)
end

export PointSequence
export @PointSequence