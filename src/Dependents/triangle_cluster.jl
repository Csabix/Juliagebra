# ? ---------------------------------
# ! TriangleClusterPlan
# ? ---------------------------------

mutable struct TriangleClusterPlan <: RenderedPlanDNA
    _plan::RenderedPlan
    _mesh::Mesh
    _transform::Mat4T{Float64}
    _color::Vec3F
    _transparent::Bool

    function TriangleClusterPlan(callback::Function,plans::Vector{T},mesh,transform,color,transparent) where {T<:PlanDNA}
        _mesh = Mesh(get_positions(mesh),get_indices(mesh))
        new(RenderedPlan(callback,plans),_mesh,transform,color,transparent)
    end
end

_RenderedPlan_(self::TriangleClusterPlan)::RenderedPlan = return self._plan
Base.string(self::TriangleClusterPlan)::String = return "Triangle cluster"

# ? ---------------------------------
# ! TriangleClusterDependent
# ? ---------------------------------

mutable struct TriangleClusterDependent <: RenderedDependentDNA
    _renderedDependent::RenderedDependent
    _mesh::Mesh
    _transform::Mat4T{Float64}
    _color::Vec3F
    _transparent::Bool
    
    function TriangleClusterDependent(plan::TriangleClusterPlan)
        new(RenderedDependent(plan),plan._mesh,plan._transform,plan._color,plan._transparent)
    end
end

Plan2Dependent(plan::TriangleClusterPlan)::TriangleClusterDependent = TriangleClusterDependent(plan)

Base.string(self::TriangleClusterDependent)::String =  return "Triangle cluster"
_RenderedDependent_(self::TriangleClusterDependent)::RenderedDependent = return self._renderedDependent

onNodeEval(self::TriangleClusterDependent) = evalCallbackDp(self)

evalCallbackDpReturn(self::TriangleClusterDependent,triangles::Vector{Vec3D}) = self._mesh = Mesh(triangles)
evalCallbackDpReturn(self::TriangleClusterDependent,triangles::Vector) = self._mesh = Mesh([Vec3D(v[1],v[2],v[3]) for v in triangles])
function evalCallbackDpReturn(self::TriangleClusterDependent,position_indices::Tuple{Any,Vector{UInt32}})
    evalCallbackDpReturn(self, position_indices[1])
    self._mesh = Mesh(self._mesh.positions,position_indices[2])
end
function evalCallbackDpReturn(self::TriangleClusterDependent,position_indices::Tuple{Any,Vector})
    evalCallbackDpReturn(self, position_indices[1])
    self._mesh = Mesh(self._mesh.positions,UInt32.position_indices[2])
end
evalCallbackDpReturn(self::TriangleClusterDependent,v::Mesh) = self._mesh = v
evalCallbackDpReturn(self::TriangleClusterDependent,v::AbstractMatrix) = self._transform = Mat4T{Float64}(v)
evalCallbackDpReturn(self::TriangleClusterDependent,::Nothing) = self._transform = dmat4(0.0)


function _get_positions(self::TriangleClusterDependent)
    return isnothing(self._mesh.indices) ? [Vec4F(pos...,1) for pos in self._mesh.positions] : [Vec4F(self._mesh.positions[index+1]...,1) for index in self._mesh.indices]
end

struct TriangleCluster
    _mesh::Mesh
    _transform::Mat4T{Float64}

    TriangleCluster(dep::TriangleClusterDependent) = new(dep._mesh,dep._transform)
end

function get_triangles(triangle_cluster::TriangleCluster)
    p = isapprox(triangle_cluster._transform, mat4(1.0)) ? 
        triangle_cluster._mesh.positions : 
        [begin
         pp = triangle_cluster._transform * Vec4D(p.x,p.y,p.z,1.0)
         Vec3D(pp.x,pp.y,pp.z)
         end
         for p in triangle_cluster._mesh.positions]

    let ind = triangle_cluster._mesh.indices
        if isnothing(ind)
            return ((p[i], p[i+1], p[i+2]) for i in 1:3:length(p))
        else
            return ((p[ind[i]+1], p[ind[i+1]+1], p[ind[i+2]+1]) for i in 1:3:length(ind))
        end
    end
end

function get_positions(triangle_cluster::TriangleCluster)::Vector{Vec3D}
    p = isapprox(triangle_cluster._transform, mat4(1.0)) ? 
        triangle_cluster._mesh.positions : 
        [begin
         pp = triangle_cluster._transform * Vec4D(p.x,p.y,p.z,1.0)
         Vec3D(pp.x,pp.y,pp.z)
         end
         for p in triangle_cluster._mesh.positions]

    return isnothing(triangle_cluster._mesh.indices) ? p : unique(p)
end

evalCallbackDpEntry(self::TriangleClusterDependent)::TriangleCluster = TriangleCluster(self)

# ? ---------------------------------
# ! TriangleClusterRenderer
# ? ---------------------------------

mutable struct TriangleClusterRenderer <: RendererDNA{TriangleClusterDependent}
    _renderer::Renderer{TriangleClusterDependent}

    _shader_calc_normals::ShaderProgram
    _shader_id::ShaderProgram
    _shader_opaque::ShaderProgram
    _shader_transparent::ShaderProgram

    _buffers::Vector{BufferArray}
    _matrices::Vector{Mat4T{Float32}}
    _transparent::Vector{Bool}

    _need_barrier::Bool


    function TriangleClusterRenderer(context::OpenGLData)
        renderer = Renderer{TriangleClusterDependent}(context)

        id = ShaderProgram([("mesh/mesh.vert",["ID"]),("mesh/mesh.frag",["ID"])],["MVP"])
        opaque = ShaderProgram([("mesh/mesh.vert",["OPAQUE"]),("mesh/mesh.frag",["OPAQUE"])],["MVP","MIT","lightDirCam","lightDirSide"])
        transparent = ShaderProgram([("mesh/mesh.vert",["TRANSPARENT"]),("mesh/mesh.frag",["TRANSPARENT"])],["MVP","MIT","lightDirCam","lightDirSide"])
        calc_normals = ShaderProgram(["calc_normals.comp"])

        new(renderer,
            calc_normals,id,opaque,transparent,
            Vector{BufferArray}(),Vector{Mat4T{Float32}}(),Vector{Bool}(),
            false)
    end
end

_Renderer_(self::TriangleClusterRenderer) = return self._renderer
Base.string(self::TriangleClusterRenderer) = return "Triangle cluster renderer"

function added!(self::TriangleClusterRenderer,cluster::TriangleClusterDependent)
    onNodeEval(cluster)
    buffer = BufferArray{Tuple{Vec4F,Vec4F,Vec3F}}()
    positions = _get_positions(cluster)
    upload!(buffer,1,positions,GL_DYNAMIC_STORAGE_BIT)
    reserve!(buffer,2,length(positions),0)
    upload!(buffer,3,fill(cluster._color,length(positions)),0)

    push!(self._buffers,buffer)
    push!(self._matrices,cluster._transform)
    push!(self._transparent,cluster._transparent)

    activate(self._shader_calc_normals)
    bind_ssbo(buffer[1],0)
    bind_ssbo(buffer[2],1)
    glDispatchCompute(cld(length(positions),64),1,1);
end

setRenderedID!(renderer::TriangleClusterRenderer,dependent::TriangleClusterDependent,id) = return nothing

function addedAll!(self::TriangleClusterRenderer)
    glMemoryBarrier(GL_VERTEX_ATTRIB_ARRAY_BARRIER_BIT)
end

function sync!(self::TriangleClusterRenderer,cluster::TriangleClusterDependent)
    buffer = self._buffers[getObserverID(cluster)]
    if cluster._transform != self._matrices[getObserverID(cluster)]
        self._matrices[getObserverID(cluster)] = cluster._transform
    else
        positions = _get_positions(cluster)
        if length(positions) != length(buffer[1])
            upload!(buffer,1,positions,GL_DYNAMIC_STORAGE_BIT)
            reserve!(buffer,2,length(positions),0)
            upload!(buffer,3,fill(cluster._color,length(positions)),0)
        else
            upload!(buffer,1,positions)
        end
        activate(self._shader_calc_normals)
        bind_ssbo(buffer[1],0)
        bind_ssbo(buffer[2],1)
        glDispatchCompute(cld(length(positions),64),1,1);
        self._need_barrier = true
    end
end

function syncAll!(self::TriangleClusterRenderer)
    if self._need_barrier
        glMemoryBarrier(GL_VERTEX_ATTRIB_ARRAY_BARRIER_BIT)
        self._need_barrier = false
    end
end

function id_pass!(self::TriangleClusterRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    glDisable(GL_CULL_FACE)
    
    activate(self._shader_id)
    for i in 1:length(self._buffers)
        if self._transparent[i] || length(self._buffers[i]) == 0 continue end
        uniform(self._shader_id,"MVP",vp*self._matrices[i])
        draw(self._buffers[i],GL_TRIANGLES)
    end

    glEnable(GL_CULL_FACE)
    return nothing
end

function opaque_pass!(self::TriangleClusterRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    (cam_light, side_light) = get_lights(cam)
    glDisable(GL_CULL_FACE)
    
    activate(self._shader_opaque)
    uniform(self._shader_opaque,"lightDirCam",-cam_light)
    uniform(self._shader_opaque,"lightDirSide",-side_light)
    for i in 1:length(self._buffers)
        if self._transparent[i] || length(self._buffers[i]) == 0 continue end
        uniform(self._shader_opaque,"MVP",vp*self._matrices[i])
        uniform(self._shader_opaque,"MIT",inv(transpose(self._matrices[i])))
        draw(self._buffers[i],GL_TRIANGLES)
    end

    glEnable(GL_CULL_FACE)
    return nothing
end

function transparent_pass!(self::TriangleClusterRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    (cam_light, side_light) = get_lights(cam)
    glDisable(GL_CULL_FACE)
    
    activate(self._shader_transparent)
    uniform(self._shader_transparent,"lightDirCam",-cam_light)
    uniform(self._shader_transparent,"lightDirSide",-side_light)
    for i in 1:length(self._buffers)
        if !self._transparent[i] || length(self._buffers[i]) == 0 continue end
        uniform(self._shader_opaque,"MVP",vp*self._matrices[i])
        uniform(self._shader_opaque,"MIT",inv(transpose(self._matrices[i])))
        draw(self._buffers[i],GL_TRIANGLES)
    end

    glEnable(GL_CULL_FACE)
    return nothing
end

function destroy!(self::TriangleClusterRenderer)
    destroy!(self._shader_id)
    destroy!(self._shader_opaque)
    destroy!(self._shader_transparent)
    destroy!.(self._buffers)
end

function Plan2Observer(self::OpenGLData,plan::TriangleClusterPlan)
    return SingleRendererTactic(self,_TRIANGLE_CLUSTER_RENDERER,TriangleClusterRenderer)::TriangleClusterRenderer
end

export TriangleCluster
export get_triangles
export get_positions