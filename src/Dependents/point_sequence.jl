mutable struct PointSequenceDependent <:RenderedDependentDNA
    _renderedDependent::RenderedDependent
    _coords::Vector{Vec3D}
    _color::Union{Nothing,UInt32} 
    _style::Union{Nothing,UInt8} 
    _size::Union{Nothing,UInt8} 

    # YELLOW Thread
    function PointSequenceDependent(callback::Function,dependents::Vector{<:DependentDNA},
                                    color::Union{Nothing,UInt32},style::Union{Nothing,UInt8},size::Union{Nothing,UInt8})
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
    _style::PointStyle

    # GREEN Thread
    function PointSequences(context::OpenGLData) 
        renderer = Renderer{PointSequenceDependent}(context)
        refs = Vector{UInt32}()
        style = theme_style(context._theme,pointsequence_style)
        new(renderer,context._renderers,refs,style)
    end
end

_Renderer_(self::PointSequences) = return self._renderer
Base.string(self::PointSequences) = return "PointSequences($(length(self._buffers)))"

function unpack_style(self::PointSequences,point_cloud::PointSequenceDependent)

    color = isnothing(point_cloud._color) ? get_style_color(self._style) : point_cloud._color
    
    style = isnothing(point_cloud._style) ? get_style_style_point(self._style) : point_cloud._style
    
    size = isnothing(point_cloud._size) ? get_style_size_int(self._style) : point_cloud._size

    return color,style,size
end

# GREEN Thread
function added!(self::PointSequences,point_cloud::PointSequenceDependent)
    aID = UInt32(getGraphID(point_cloud) + ID_LOWER_BOUND)

    (c,st,si) = unpack_style(self,point_cloud)

    ref = add_dynamic!(self._renderers.point,
                       (Vec3F(coord) for coord in point_cloud._coords),
                       cycle([c]),
                       cycle([st]),
                       cycle([UInt8(si)]),
                       cycle([aID]))
    push!(self._refs, ref);
end

function update_style!(self::PointSequences,theme::Theme)
    style = theme_style(theme,pointsequence_style)
    self._style = style
end

function sync!(self::PointSequences,point_cloud::PointSequenceDependent)
    aID = UInt32(getGraphID(point_cloud) + ID_LOWER_BOUND)

    (c,st,si) = unpack_style(self,point_cloud)

    ref = self._refs[getObserverID(point_cloud)]
    update_dyncamic!(self._renderers.point, ref,
                    (Vec3F(coord) for coord in point_cloud._coords),
                    cycle([c]),
                    cycle([st]),
                    cycle([UInt8(si)]),
                    cycle([aID]))
end

function destroy!(self::PointSequences) end

# YELLOW Thread
Dependent2Observer(app::AppDNA,::PointSequenceDependent)::PointSequences = getDependentObservers(app)[_POINT_SEQUENCES]

function PointSequence(callback::Function,dependents::Vector{<:DependentDNA}=DependentDNA[],color_style::Union{Nothing,String}=nothing;
    color=nothing,style=nothing,size=nothing)::PointSequenceDependent
    (c, st) = parse_point_color_style(color_style, color, style)

    si = isnothing(size) ? nothing : UInt8(round(UInt8,size))

    Build!(PointSequenceDependent(callback,dependents,c,st,si))
end

PointSequence(dependents::Vector{<:DependentDNA},color_style::Union{Nothing,String}=nothing;
    color=nothing,style=nothing,size=nothing)::PointSequenceDependent =
PointSequence(_deps_collect,dependents,color_style;color=color,style=style,size=size)

macro PointSequence(callback::Expr, args...)
    (positional_args, kw_args) = _parse_macro_arguments((:color_style,),(:color, :style, :size), args...)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.PointSequence,
                                positional_args, kw_args)
end

export PointSequence
export @PointSequence