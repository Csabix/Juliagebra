mutable struct DynamicPointCloudDependent <:RenderedDependentDNA
    _renderedDependent::RenderedDependent
    _coords::Vector{Vec3D}
    _color::Vec3F
    _width::Float32

    # YELLOW Thread
    function DynamicPointCloudDependent(callback::Function,dependents::Vector{<:DependentDNA},color::Tuple{Real,Real,Real},width::Real)
        dependent = RenderedDependent(callback,dependents)
        coords = Vector{Vec3D}()

        new(dependent,coords,color,width)
    end
end

_RenderedDependent_(self::DynamicPointCloudDependent)::RenderedDependent = return self._renderedDependent
Base.string(self::DynamicPointCloudDependent) = "PointCloud[$(_Dependent_(self)._graphID) - $(string(length(_Dependent_(self)._graphParents))) - $(string(length(_Dependent_(self)._graphChain)))]"

# YELLOW Thread
# RED Thread
onNodeEval(self::DynamicPointCloudDependent) = evalCallbackDp(self)

evalCallbackDpEntry(self::DynamicPointCloudDependent)::Vector{Vec3D} = self._coords

evalCallbackDpReturn(self::DynamicPointCloudDependent,coords::Vector{Vec3D})   = self._coords = coords
evalCallbackDpReturn(self::DynamicPointCloudDependent,coords::Vector{Vec3F})   = self._coords = Vec3D.(coords)
evalCallbackDpReturn(self::DynamicPointCloudDependent,coords::Vector{<:Tuple}) = self._coords = [Vec3D(coord...) for coord in coords]
evalCallbackDpReturn(self::DynamicPointCloudDependent,coords::Vector{<:AbstractVector}) = self._coords = [Vec3D(coord...) for coord in coords]
evalCallbackDpReturn(self::DynamicPointCloudDependent,::Nothing) = self._coords = Vec3D[]

mutable struct DynamicPointClouds <:RendererDNA{DynamicPointCloudDependent}
    _renderer::Renderer{DynamicPointCloudDependent}
    _indexes::Vector{UInt32}

    # GREEN Thread
    function DynamicPointClouds(context::OpenGLData) 
        renderer = Renderer{DynamicPointCloudDependent}(context)
        indexes = Vector{UInt32}()
        new(renderer,indexes)
    end
end

_Renderer_(self::DynamicPointClouds) = return self._renderer
Base.string(self::DynamicPointClouds) = return "PointCloudRenderer($(length(self._buffers)))"

# GREEN Thread
function added!(self::DynamicPointClouds,point_cloud::DynamicPointCloudDependent)
    aID = UInt32(getGraphID(point_cloud) + ID_LOWER_BOUND)
    N = length(point_cloud._coords)
    ref = add_dynamic!(Val{:Point}(),
                       (Vec3F(coord) for coord in point_cloud._coords),
                       cycle([POINT_NONE]),
                       cycle([point_cloud._color]),
                       cycle([UInt8(point_cloud._width)]),
                       cycle([aID]))
    push!(self._indexes, ref);
end

function sync!(self::DynamicPointClouds,point_cloud::DynamicPointCloudDependent)
    aID = UInt32(getGraphID(point_cloud) + ID_LOWER_BOUND)
    index = self._indexes[getObserverID(point_cloud)]
    update_dyncamic!(Val{:Point}(), index,
                    (Vec3F(coord) for coord in point_cloud._coords),
                    cycle([POINT_NONE]),
                    cycle([point_cloud._color]),
                    cycle([UInt8(point_cloud._width)]),
                    cycle([aID]))
end

function destroy!(self::DynamicPointClouds) end

# YELLOW Thread
Dependent2Observer(app::AppDNA,::DynamicPointCloudDependent)::DynamicPointClouds = getOpenGL(app)._renderers[_POINT_CLOUDS_DYNAMIC]

PointCloud(callback::Function,dependents=Vector{DependentDNA}();color=(0.0,1.0,1.0),width=25.0f0)::DynamicPointCloudDependent =
build!(DynamicPointCloudDependent(callback,dependents,color,width))

PointCloud(dependents::Vector{DependentDNA};color=(0.0,1.0,1.0),width=25.0f0)::DynamicPointCloudDependent =
PointCloud(_deps_collect,dependents;color=color,width=width)

macro PointCloud(callback::Expr, kw_args...)
    parsed_kw_args = _parse_macro_kw_args([:color, :width], kw_args...)
    callback = _validate_callback_expr(callback, 0)
    return _create_ctor_wrapper(callback, __module__, Juliagebra.PointCloud; parsed_kw_args...)
end

export PointCloud
export @PointCloud