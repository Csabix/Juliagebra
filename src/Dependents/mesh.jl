# ? ---------------------------------
# ! MeshPlan
# ? ---------------------------------

mutable struct MeshPlan <: RenderedPlanDNA
    _plan::RenderedPlan
    _positions::Vector{Vec3F}
    _normals::Vector{Vec3F}
    _indices::Vector{UInt32}

    function MeshPlan(callback::Function,plans::Vector{T},positions,normals,indices) where {T<:PlanDNA}
        new(RenderedPlan(callback,plans),positions,normals,indices)
    end
end

_RenderedPlan_(self::MeshPlan)::RenderedPlan = return self._plan
Base.string(self::MeshPlan)::String = return "Mesh"


# ? ---------------------------------
# ! MeshDependent
# ? ---------------------------------

mutable struct MeshDependent <: RenderedDependentDNA
    _renderedDependent::RenderedDependent
    _positions::Vector{Vec3F}
    _normals::Vector{Vec3F}
    _indices::Vector{UInt32}
    
    function MeshDependent(plan::MeshPlan)
        new(RenderedDependent(plan),plan._positions,plan._normals,plan._indices)
    end
end

# ! Must have
function Plan2Dependent(plan::MeshPlan)::MeshDependent
    return MeshDependent(plan)
end

Base.string(self::MeshDependent)::String =  return "Mesh"
_RenderedDependent_(self::MeshDependent)::RenderedDependent = return self._renderedDependent

function runCallbacks(self::MeshDependent)
end

function onNodeEval(self::MeshDependent)
    runCallbacks(self)
end

evalCallbackDpReturn(self::MeshDependent,v) = begin end
evalCallbackDpReturn(self::MeshDependent,v::Vec3D) = begin end
evalCallbackDpReturn(self::MeshDependent,v::Vec3F) = begin end
evalCallbackDpReturn(self::MeshDependent,v::Nothing) = begin end

# ? ---------------------------------
# ! MeshRenderer
# ? ---------------------------------

mutable struct MeshRenderer <: RendererDNA{MeshDependent}
    _renderer::Renderer{MeshDependent}

    _shader::ShaderProgram
    _buffers::Vector{IndexedTypedBufferArray}

    function MeshRenderer(context::OpenGLData)
        renderer = Renderer{MeshDependent}(context)

        shader = ShaderProgram(sp("surface/surface.vert"),sp("surface/surface_opaque.frag"),["VP","lightDirCam","lightDirSide"])
        buffers = Vector{IndexedTypedBufferArray}()

        new(renderer,shader,buffers)
    end
end

_Renderer_(self::MeshRenderer) = return self._renderer
Base.string(self::MeshRenderer) = return "MeshRenderer"


# ! Must have
function added!(self::MeshRenderer,mesh::MeshDependent)
    buffer = IndexedTypedBufferArray{Tuple{Vec3F,Vec3F,Vec3F}}()
    upload!(buffer,1,mesh._positions,GL_STATIC_DRAW)
    upload!(buffer,2,mesh._normals,GL_STATIC_DRAW)
    colors = fill(Vec3F(1.0,0.3,0.4),length(mesh._positions))
    upload!(buffer,3,colors,GL_STATIC_DRAW)
    uploadIndexes!(buffer,mesh._indices,GL_STATIC_DRAW)

    push!(self._buffers,buffer)
end

setRenderedID!(renderer::MeshRenderer,dependent::MeshDependent,id) = return nothing

# ! Must have
function addedAll!(self::MeshRenderer)
end

# ! Must have
function sync!(self::MeshRenderer,curve::MeshDependent)
end

# ! Must have
function syncAll!(self::MeshRenderer)
end

function opaque_pass!(self::MeshRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    (cam_light, side_light) = get_lights(cam)
    glDisable(GL_CULL_FACE)
    activate(self._shader)

    setUniform!(self._shader,"VP",vp)
    setUniform!(self._shader,"lightDirCam",-cam_light)
    setUniform!(self._shader,"lightDirSide",-side_light)
    @time_gpu_begin Dependent Mesh OPAQUE_PASS
    for buffer in self._buffers
        draw(buffer,GL_TRIANGLES)
    end
    @time_gpu_end Dependent Mesh OPAQUE_PASS

    glEnable(GL_CULL_FACE)
    return nothing
end

# ! Must have
function destroy!(self::MeshRenderer)
end

# ! Must have
function Plan2Observer(self::OpenGLData,plan::MeshPlan)
    return SingleRendererTactic(self,_MESH_RENDERER,MeshRenderer)::MeshRenderer
end