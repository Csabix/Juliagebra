mutable struct StaticPointCloudDependent <:RenderedDependentDNA
    _renderedDependent::RenderedDependent
    _coords::Vector{Vec3D}
    _color::Vec3F
    _width::Float32

    # YELLOW Thread
    function StaticPointCloudDependent(callback::Function,dependents::Vector{<:DependentDNA},color::Tuple{Real,Real,Real},width::Real)
        dependent = RenderedDependent(callback,dependents)
        coords = Vector{Vec3D}()

        new(dependent,coords,color,width)
    end
end

_RenderedDependent_(self::StaticPointCloudDependent)::RenderedDependent = return self._renderedDependent
Base.string(self::StaticPointCloudDependent) = "PointCloud[$(_Dependent_(self)._graphID) - $(string(length(_Dependent_(self)._graphParents))) - $(string(length(_Dependent_(self)._graphChain)))]"

# YELLOW Thread
# RED Thread
onNodeEval(self::StaticPointCloudDependent) = evalCallbackDp(self)

evalCallbackDpEntry(self::StaticPointCloudDependent)::Vector{Vec3D} = self._coords

function evalCallbackDpReturn(self::StaticPointCloudDependent,coords::Vector{Vec3D})
    @assert length(self._coords) == length(coords) || length(self._coords) == 0
    self._coords = coords
end
evalCallbackDpReturn(self::StaticPointCloudDependent,coords::Vector{Vec3F})  = evalCallbackDpReturn(self,Vec3D.(coords))
evalCallbackDpReturn(self::StaticPointCloudDependent,coords::Vector{Tuple})  = evalCallbackDpReturn(self,[Vec3D(coord...) for coord in coords])
evalCallbackDpReturn(self::StaticPointCloudDependent,coords::Vector{Vector}) = evalCallbackDpReturn(self,[Vec3D(coord...) for coord in coords])
evalCallbackDpReturn(self::StaticPointCloudDependent,::Nothing) = fill!(self._coords, Vec3DNan)

mutable struct StaticPointClouds <:RendererDNA{StaticPointCloudDependent}
    _renderer::Renderer{StaticPointCloudDependent}
    _indexes::Vector{UInt32}

    # GREEN Thread
    function StaticPointClouds(context::OpenGLData) 
        renderer = Renderer{StaticPointCloudDependent}(context)
        indexes = Vector{UInt32}()
        new(renderer,indexes)
    end
end

_Renderer_(self::StaticPointClouds) = return self._renderer
Base.string(self::StaticPointClouds) = return "PointCloudRenderer($(length(self._buffers)))"

# GREEN Thread
function added!(self::StaticPointClouds,point_cloud::StaticPointCloudDependent)
    aID = UInt32(getGraphID(point_cloud) + ID_LOWER_BOUND)
    ref = add!(Val{:Point}(),
               (Vec3F(coord) for coord in point_cloud._coords),
               cycle([POINT_NONE]),
               cycle([point_cloud._color]),
               cycle([UInt8(point_cloud._width)]),
               cycle([aID]))::UInt32
    push!(self._indexes, ref);
end

function sync!(self::StaticPointClouds,point_cloud::StaticPointCloudDependent)
    index = self._indexes[getObserverID(point_cloud)]
    view = update_coords!(Val{:Point}(),index,UInt32(length(point_cloud._coords)))
    for (i, coord) in enumerate(point_cloud._coords)
        view[i] = Vec3F(coord)
    end
end

function destroy!(self::StaticPointClouds) end

# YELLOW Thread
Dependent2Observer(app::AppDNA,::StaticPointCloudDependent)::StaticPointClouds = getOpenGL(app)._renderers[_POINT_CLOUDS_STATIC]

StaticPointCloud(callback::Function,dependents=Vector{<:DependentDNA}();color=(0.0,1.0,1.0),width=25.0f0)::StaticPointCloudDependent =
build!(StaticPointCloudDependent(callback,dependents,color,width))

StaticPointCloud(dependents::Vector{<:DependentDNA};color=(0.0,1.0,1.0),width=25.0f0)::StaticPointCloudDependent =
StaticPointCloud(_deps_collect,dependents;color=color,width=width)

function StaticPointCloud(positions)
    GenericValueHolder(_deps_collect,Vector{Vec3D},[Point(p...) for p in positions])
end

macro StaticPointCloud(callback::Expr, kw_args...)
    parsed_kw_args = _parse_macro_kw_args([:color, :width], kw_args...)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.StaticPointCloud; parsed_kw_args...)
end

export StaticPointCloud
export @StaticPointCloud