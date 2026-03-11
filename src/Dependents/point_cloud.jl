
# ? ---------------------------------
# ! PointCloudDependent
# ? ---------------------------------

mutable struct PointCloudDependent <:RenderedDependentDNA
    _renderedDependent::RenderedDependent
    _coords::Vector{Vec3D}
    _color::Vec3F
    _width::Float32

    # YELLOW Thread
    function PointCloudDependent(callback::Function,dependents::Vector{<:DependentDNA},color::Tuple{Real,Real,Real},width::Real)
        dependent = RenderedDependent(callback,dependents)
        coords = Vector{Vec3D}()

        new(dependent,coords,color,width)
    end
end

_RenderedDependent_(self::PointCloudDependent)::RenderedDependent = return self._renderedDependent
Base.string(self::PointCloudDependent) = "PointCloud[$(_Dependent_(self)._graphID) - $(string(length(_Dependent_(self)._graphParents))) - $(string(length(_Dependent_(self)._graphChain)))]"

# YELLOW Thread
# RED Thread
onNodeEval(self::PointCloudDependent) = evalCallbackDp(self)

evalCallbackDpEntry(self::PointCloudDependent)::Vector{Vec3D} = self._coords

evalCallbackDpReturn(self::PointCloudDependent,coords) = self._coords  = coords
evalCallbackDpReturn(self::PointCloudDependent,coords::Vector{Vec3D})  = self._coords = coords
evalCallbackDpReturn(self::PointCloudDependent,coords::Vector{Vec3F})  = self._coords = [Vec3D(coord) for coord in coords]
evalCallbackDpReturn(self::PointCloudDependent,coords::Vector{Tuple})  = self._coords = [Vec3D(coord...) for coord in coords]
evalCallbackDpReturn(self::PointCloudDependent,coords::Vector{Vector}) = self._coords = [Vec3D(coord...) for coord in coords]
evalCallbackDpReturn(self::PointCloudDependent,::Nothing) = self._coords = []

# ? ---------------------------------
# ! PointCloudRenderer
# ? ---------------------------------

mutable struct PointCloudRenderer <:RendererDNA{PointCloudDependent}
    _renderer::Renderer{PointCloudDependent}

    _shader_id::ShaderProgram
    _shader_opaque::ShaderProgram
    _buffers::Vector{BufferArray}
    _widths::Vector{Float32}
    _colors::Vector{Vec3F}

    # GREEN Thread
    function PointCloudRenderer(context::OpenGLData) 
        renderer = Renderer{PointCloudDependent}(context)
        shader_id = ShaderProgram(["point_cloud/point_cloud.vert","point_cloud/point_cloud_id.frag"],["VP","pointSize"])
        shader_opaque = ShaderProgram(["point_cloud/point_cloud.vert","point_cloud/point_cloud.frag"],["VP","pointSize","lightDirSideView","drawColor"])

        new(
            renderer,
            shader_id,shader_opaque,
            Vector{BufferArray}(),
            Vector{Float32}(),
            Vector{Vec3F}())
    end
end

_Renderer_(self::PointCloudRenderer) = return self._renderer
Base.string(self::PointCloudRenderer) = return "PointCloudRenderer($(length(self._buffers)))"

# GREEN Thread
function added!(self::PointCloudRenderer,point_cloud::PointCloudDependent)
    buffer = BufferArray{Tuple{Vec3F}}(MappedBuffer)
    upload!(buffer,1,[Vec3F(coord) for coord in point_cloud._coords],0)
    push!(self._buffers,buffer)
    push!(self._widths,point_cloud._width)
    push!(self._colors,point_cloud._color)
end

# GREEN Thread
addedAll!(self::PointCloudRenderer) = return nothing

# GREEN Thread
function sync!(self::PointCloudRenderer,point_cloud::PointCloudDependent)
    if length(self._buffers[getObserverID(point_cloud)][1]) == length(point_cloud._coords)
        waitt(self._buffers[getObserverID(point_cloud)][1])
        copyto!(self._buffers[getObserverID(point_cloud)][1],[Vec3F(coord) for coord in point_cloud._coords])
    else
        upload!(self._buffers[getObserverID(point_cloud)],1,[Vec3F(coord) for coord in point_cloud._coords],0)
    end
    self._widths[getObserverID(point_cloud)] = point_cloud._width
    self._colors[getObserverID(point_cloud)] = point_cloud._color
end

# GREEN Thread
syncAll!(self::PointCloudRenderer) = return nothing

function id_pass!(self::PointCloudRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    activate(self._shader_id)
    uniform(self._shader_id,"VP",vp)
    @time_gpu_begin Dependent Point_Cloud ID_PASS
    for i in 1:length(self._buffers)
        uniform(self._shader_id,"pointSize",self._widths[i])
        draw(self._buffers[i],GL_POINTS)
    end
    @time_gpu_end Dependent Point_Cloud ID_PASS
    return nothing
end

function opaque_pass!(self::PointCloudRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    (_, view, _) = get_matrices(cam)
    (_, side_light) = get_lights(cam)

    activate(self._shader_opaque)
    uniform(self._shader_opaque,"VP",vp)
    uniform(self._shader_opaque,"lightDirSideView", view[1:3,1:3] * side_light)
    @time_gpu_begin Dependent Point_Cloud OPAQUE_PASS
    for i in 1:length(self._buffers)
        uniform(self._shader_opaque,"pointSize",self._widths[i])
        uniform(self._shader_opaque,"drawColor",self._colors[i])
        draw(self._buffers[i],GL_POINTS)
        lockk(self._buffers[i][1])
    end
    @time_gpu_end Dependent Point_Cloud OPAQUE_PASS
    return nothing
end

is_occluder(self::PointCloudRenderer)::Bool = false

function destroy!(self::PointCloudRenderer) 
    destroy!(self._shader_id)
    destroy!(self._shader_opaque)
    destroy!.(self._buffers)
end

# YELLOW Thread
Dependent2Observer(app::AppDNA,::PointCloudDependent)::PointCloudRenderer = getOpenGL(app)._renderers[5]

# ? ---------------------------------
# ! PointCloud
# ? ---------------------------------

_deps_collect_add!(vec::Vector{Vec3D},v) = push!(vec,v)
_deps_collect_add!(vec::Vector{Vec3D},v::Vector) = append!(vec,v)
function _deps_collect_add!(vec::Vector{Vec3D},intersectons::IntersectionCalculatorDependent)
    i = 1
    while true
        v = intersectons[i]
        if isnothing(v) return end
        push!(vec,v)
        i += 1
    end
end
function _deps_collect(deps...)
    result = Vector{Vec3D}()
    for dep in deps
        _deps_collect_add!(result,dep)
    end
    return result
end

# YELLOW Thread
PointCloud(callback::Function,dependents=Vector{DependentDNA}();color=(0.0,1.0,1.0),width=25.0f0)::PointCloudDependent =
build!(PointCloudDependent(callback,dependents,color,width))

# YELLOW Thread
PointCloud(dependents::Vector{<:DependentDNA}) = GenericValueHolder(_deps_collect,Vector{Vec3D},dependents)

# YELLOW Thread
function PointCloud(positions) 
    #println(positions)
    return PointCloud([Point(p...) for p in positions])
end

export PointCloud