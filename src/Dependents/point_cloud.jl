# ? ---------------------------------
# ! PointCloudPlan
# ? ---------------------------------

mutable struct PointCloudPlan <: RenderedPlanDNA
    _plan::RenderedPlan
    _color::Vec3F
    _width::Float32
        
    function PointCloudPlan(callback::Function,plans::Vector{T},color::Tuple{Real,Real,Real},width::Real) where {T<:PlanDNA}
        new(RenderedPlan(callback,plans),color,width)
    end
end

_RenderedPlan_(self::PointCloudPlan)::RenderedPlan = return self._plan
Base.string(self::PointCloudPlan)::String = return "PointCloudPlan[$(string(length(self._plans)))] -> $(string(_Plan_(self)._dependent))"

# ? ---------------------------------
# ! PointCloudDependent
# ? ---------------------------------

mutable struct PointCloudDependent <:RenderedDependentDNA
    _renderedDependent::RenderedDependent
    _coords::Vector{Vec3D}
    _color::Vec3F
    _width::Float32

    function PointCloudDependent(plan::PointCloudPlan)
        new(RenderedDependent(plan),Vector{Vec3D}(),plan._color,plan._width)
    end
end

function Plan2Dependent(plan::PointCloudPlan)::PointCloudDependent
    return PointCloudDependent(plan)
end

_RenderedDependent_(self::PointCloudDependent)::RenderedDependent = return self._renderedDependent
Base.string(self::PointCloudDependent) = "PointCloud[$(_Dependent_(self)._graphID) - $(string(length(_Dependent_(self)._graphParents))) - $(string(length(_Dependent_(self)._graphChain)))]"


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

setRenderedID!(self::PointCloudRenderer,item::PointCloudDependent,id) = return nothing

function added!(self::PointCloudRenderer,point_cloud::PointCloudDependent)
    onNodeEval(point_cloud)
    buffer = BufferArray{Tuple{Vec3F}}(MappedBuffer)
    upload!(buffer,1,[Vec3F(coord) for coord in point_cloud._coords],0)
    push!(self._buffers,buffer)
    push!(self._widths,point_cloud._width)
    push!(self._colors,point_cloud._color)
end

addedAll!(self::PointCloudRenderer) = return nothing

function sync!(self::PointCloudRenderer,point_cloud::PointCloudDependent)
    if length(self._buffers[getObserverID(point_cloud)][1]) == length(point_cloud._coords)
        wait(self._buffers[getObserverID(point_cloud)][1])
        copyto!(self._buffers[getObserverID(point_cloud)][1],[Vec3F(coord) for coord in point_cloud._coords])
    else
        upload!(self._buffers[getObserverID(point_cloud)],1,[Vec3F(coord) for coord in point_cloud._coords],0)
    end
    self._widths[getObserverID(point_cloud)] = point_cloud._width
    self._colors[getObserverID(point_cloud)] = point_cloud._color
end

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
        lock(self._buffers[i][1])
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

function Plan2Observer(self::OpenGLData,plan::PointCloudPlan)
    return SingleRendererTactic(self,_POINT_CLOUD_RENDERER,PointCloudRenderer)::PointCloudRenderer
end