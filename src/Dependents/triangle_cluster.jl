# ? ---------------------------------
# ! TriangleClusterPlan
# ? ---------------------------------

mutable struct TriangleClusterPlan <: RenderedPlanDNA
    _plan::RenderedPlan
    _mesh::SceneMesh

    function TriangleClusterPlan(callback::Function,plans::Vector{T},mesh::SceneMesh) where {T<:PlanDNA}
        new(RenderedPlan(callback,plans),mesh)
    end
end

_RenderedPlan_(self::TriangleClusterPlan)::RenderedPlan = return self._plan
Base.string(self::TriangleClusterPlan)::String = return "Triangle cluster"


# ? ---------------------------------
# ! TriangleClusterDependent
# ? ---------------------------------

mutable struct TriangleClusterDependent <: RenderedDependentDNA
    _renderedDependent::RenderedDependent
    _mesh::SceneMesh
    
    function TriangleClusterDependent(plan::TriangleClusterPlan)
        new(RenderedDependent(plan),plan._mesh)
    end
end

# ! Must have
function Plan2Dependent(plan::TriangleClusterPlan)::TriangleClusterDependent
    return TriangleClusterDependent(plan)
end

Base.string(self::TriangleClusterDependent)::String =  return "Triangle cluster"
_RenderedDependent_(self::TriangleClusterDependent)::RenderedDependent = return self._renderedDependent

function onNodeEval(self::TriangleClusterDependent)
    runCallbacks(self)
end

evalCallbackDpReturn(self::TriangleClusterDependent,v) = begin end
evalCallbackDpReturn(self::TriangleClusterDependent,v::Vec3D) = begin end
evalCallbackDpReturn(self::TriangleClusterDependent,v::Vec3F) = begin end
evalCallbackDpReturn(self::TriangleClusterDependent,v::Nothing) = begin end

# ? ---------------------------------
# ! TriangleClusterRenderer
# ? ---------------------------------

mutable struct TriangleClusterRenderer <: RendererDNA{TriangleClusterDependent}
    _renderer::Renderer{TriangleClusterDependent}

    _shader_opaque::ShaderProgram
    _shader_id::ShaderProgram
    _buffer::IndexedTypedBufferArray

    _positions::Vector{Vec3F}
    _normals::Vector{Vec3F}
    _indices::Vector{UInt32}

    function TriangleClusterRenderer(context::OpenGLData)
        renderer = Renderer{TriangleClusterDependent}(context)

        id = ShaderProgram(sp("surface/surface_id.vert"),sp("surface/surface_id.frag"),["VP"])
        opaque = ShaderProgram(sp("surface/surface.vert"),sp("surface/surface_opaque.frag"),["VP","lightDirCam","lightDirSide"])
        buffer = IndexedTypedBufferArray{Tuple{Vec3F,Vec3F,Vec3F}}()

        positions = Vector{Vec3F}()
        normals = Vector{Vec3F}()
        indices = Vector{UInt32}()

        new(renderer,opaque,id,buffer,
        positions,normals,indices)
    end
end

_Renderer_(self::TriangleClusterRenderer) = return self._renderer
Base.string(self::TriangleClusterRenderer) = return "Triangle cluster renderer"


# ! Must have
function added!(self::TriangleClusterRenderer,cluster::TriangleClusterDependent)
    base_index::UInt32 = length(self._positions)
    
    append!(self._positions,get_positions(cluster._mesh))
    append!(self._normals,get_normals(cluster._mesh))
    for index in get_indices(cluster._mesh)
        push!(self._indices, index + base_index)
    end
end

setRenderedID!(renderer::TriangleClusterRenderer,dependent::TriangleClusterDependent,id) = return nothing

# ! Must have
function addedAll!(self::TriangleClusterRenderer)
    upload!(self._buffer,1,self._positions,GL_STATIC_DRAW)
    upload!(self._buffer,2,self._normals,GL_STATIC_DRAW)
    colors = fill(Vec3F(1.0,0.3,0.4),length(self._positions))
    upload!(self._buffer,3,colors,GL_STATIC_DRAW)
    uploadIndexes!(self._buffer,self._indices,GL_STATIC_DRAW)
end

# ! Must have
function sync!(self::TriangleClusterRenderer,curve::TriangleClusterDependent)
end

# ! Must have
function syncAll!(self::TriangleClusterRenderer)
end

function id_pass!(self::TriangleClusterRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    glDisable(GL_CULL_FACE)
    
    activate(self._shader_id)
    setUniform!(self._shader_id,"VP",vp)
    @time_gpu_begin Dependent TriangleCluster ID_PASS
    draw(self._buffer,GL_TRIANGLES)
    @time_gpu_end Dependent TriangleCluster ID_PASS

    glEnable(GL_CULL_FACE)
    return nothing
end

function opaque_pass!(self::TriangleClusterRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    (cam_light, side_light) = get_lights(cam)
    glDisable(GL_CULL_FACE)
    activate(self._shader_opaque)

    setUniform!(self._shader_opaque,"VP",vp)
    setUniform!(self._shader_opaque,"lightDirCam",-cam_light)
    setUniform!(self._shader_opaque,"lightDirSide",-side_light)
    @time_gpu_begin Dependent TriangleCluster OPAQUE_PASS
    draw(self._buffer,GL_TRIANGLES)
    @time_gpu_end Dependent TriangleCluster OPAQUE_PASS

    glEnable(GL_CULL_FACE)
    return nothing
end

# ! Must have
function destroy!(self::TriangleClusterRenderer)
    destroy!(self._shader_opaque)
    destroy!(self._buffer)
end

# ! Must have
function Plan2Observer(self::OpenGLData,plan::TriangleClusterPlan)
    return SingleRendererTactic(self,_TRIANGLE_CLUSTER_RENDERER,TriangleClusterRenderer)::TriangleClusterRenderer
end