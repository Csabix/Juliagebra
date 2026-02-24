# ? ---------------------------------
# ! TriangleClusterPlan
# ? ---------------------------------

mutable struct TriangleClusterPlan <: RenderedPlanDNA
    _plan::RenderedPlan
    _mesh::Mesh
    _color::Vec3F
    _transparent::Bool

    function TriangleClusterPlan(callback::Function,plans::Vector{T},mesh,color,transparent) where {T<:PlanDNA}
        _mesh = Mesh(
            collect(get_positions_it(mesh)),
            collect(get_indices_it(mesh))
        )
        new(RenderedPlan(callback,plans),_mesh,color,transparent)
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
    _color::Vec3F
    _transparent::Bool
    
    function TriangleClusterDependent(plan::TriangleClusterPlan)
        new(RenderedDependent(plan),plan._mesh,plan._color,plan._transparent)
    end
end

Plan2Dependent(plan::TriangleClusterPlan)::TriangleClusterDependent = TriangleClusterDependent(plan)

Base.string(self::TriangleClusterDependent)::String =  return "Triangle cluster"
_RenderedDependent_(self::TriangleClusterDependent)::RenderedDependent = return self._renderedDependent

onNodeEval(self::TriangleClusterDependent) = evalCallbackDp(self)

evalCallbackDpReturn(self::TriangleClusterDependent,v) = begin end
evalCallbackDpReturn(self::TriangleClusterDependent,v::Vec3D) = begin end
evalCallbackDpReturn(self::TriangleClusterDependent,v::Vec3F) = begin end
evalCallbackDpReturn(self::TriangleClusterDependent,v::Nothing) = begin end

# ? ---------------------------------
# ! TriangleCluster
# ? ---------------------------------

struct TriangleCluster
    positions::Vector{Vec3D}
    indices::Union{Nothing,Vector{UInt32}}

    function TriangleCluster(dep::TriangleClusterDependent)
        return new(dep._mesh.positions,dep._mesh.indices)
    end
end

evalCallbackDpEntry(self::TriangleClusterDependent)::TriangleCluster = TriangleCluster(self)

@inline _get_triangle(p, ::Nothing, i) = SA[p[i], p[i+1], p[i+2]]
@inline _get_triangle(p, idxs, i)      = SA[p[idxs[i]], p[idxs[i+1]], p[idxs[i+2]]]
@inline function Base.iterate(self::TriangleCluster, state::Int=1)
    source = isnothing(self.indices) ? self.positions : self.indices
    state + 2 > length(source) && return nothing
    
    return (_get_triangle(self.positions, self.indices, state), state + 3)
end

@inline Base.firstindex(self::TriangleCluster) = 1
@inline function Base.lastindex(self::TriangleCluster)
    len = isnothing(self.indices) ? length(self.positions) : length(self.indices)
    return div(len,3)
end
@inline function Base.getindex(self::TriangleCluster, index::Int)
    @boundscheck if index < firstindex(self) && index > lastindex(self)
        throw(BoundsError(self, index))
    end
    offset::Int = (index - 1) * 3 + 1
    return _get_triangle(self.positions, self.indices, offset)
end

# ? ---------------------------------
# ! TriangleClusterRenderer
# ? ---------------------------------

mutable struct TriangleClusterRenderer <: RendererDNA{TriangleClusterDependent}
    _renderer::Renderer{TriangleClusterDependent}

    _shader_id::ShaderProgram
    _shader_opaque::ShaderProgram
    _shader_transparent::ShaderProgram

    _buffer_opaque::IndexedTypedBufferArray
    _buffer_transparent::IndexedTypedBufferArray

    _positions_opaque::Vector{Vec3F}
    _colors_opaque::Vector{Vec3F}

    _positions_transparent::Vector{Vec3F}
    _colors_transparent::Vector{Vec3F}

    function TriangleClusterRenderer(context::OpenGLData)
        renderer = Renderer{TriangleClusterDependent}(context)

        id = ShaderProgram(sp("surface/surface_id.vert"),sp("surface/surface_id.frag"),["VP"])
        opaque = ShaderProgram(sp("surface/surface.vert"),sp("surface/surface_opaque.frag"),["VP","lightDirCam","lightDirSide"])
        transparent = ShaderProgram(sp("surface/surface.vert"),sp(".surface/surface_transparent.frag"),["VP","lightDirCam","lightDirSide"])

        new(renderer,
            id,opaque,transparent,
            IndexedTypedBufferArray{Tuple{Vec3F,Vec3F,Vec3F}}(),IndexedTypedBufferArray{Tuple{Vec3F,Vec3F,Vec3F}}(),
            Vector{Vec3F}(),Vector{Vec3F}(),
            Vector{Vec3F}(),Vector{Vec3F}())
    end
end

_Renderer_(self::TriangleClusterRenderer) = return self._renderer
Base.string(self::TriangleClusterRenderer) = return "Triangle cluster renderer"


# ! Must have
function added!(self::TriangleClusterRenderer,cluster::TriangleClusterDependent)
    dst_positions = cluster._transparent ? self._positions_transparent : self._positions_opaque
    dst_normals   = cluster._transparent ? self._normals_transparent   : self._normals_opaque
    dst_colors    = cluster._transparent ? self._colors_transparent    : self._colors_opaque
    dst_indices   = cluster._transparent ? self._indices_transparent   : self._indices_opaque

    base_index::UInt32 = length(dst_positions)
    
    positions = get_positions(cluster._mesh)
    append!(dst_positions,positions)
    append!(dst_colors,fill(cluster._color,length(positions)))
    append!(dst_normals,get_normals(cluster._mesh))
    for index in get_indices(cluster._mesh)
        push!(dst_indices, index + base_index)
    end
end

setRenderedID!(renderer::TriangleClusterRenderer,dependent::TriangleClusterDependent,id) = return nothing

# ! Must have
function addedAll!(self::TriangleClusterRenderer)
    upload!(self._buffer_opaque,1,self._positions_opaque,GL_STATIC_DRAW)
    upload!(self._buffer_opaque,2,self._normals_opaque,GL_STATIC_DRAW)
    upload!(self._buffer_opaque,3,self._colors_opaque,GL_STATIC_DRAW)
    uploadIndexes!(self._buffer_opaque,self._indices_opaque,GL_STATIC_DRAW)

    upload!(self._buffer_transparent,1,self._positions_transparent,GL_STATIC_DRAW)
    upload!(self._buffer_transparent,2,self._normals_transparent,GL_STATIC_DRAW)
    upload!(self._buffer_transparent,3,self._colors_transparent,GL_STATIC_DRAW)
    uploadIndexes!(self._buffer_transparent,self._indices_transparent,GL_STATIC_DRAW)
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
    if length(self._buffer_opaque) != 0 draw(self._buffer_opaque,GL_TRIANGLES) end
    @time_gpu_end Dependent TriangleCluster ID_PASS

    glEnable(GL_CULL_FACE)
    return nothing
end

function opaque_pass!(self::TriangleClusterRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    if length(self._buffer_opaque) == 0 return nothing end
    (cam_light, side_light) = get_lights(cam)
    glDisable(GL_CULL_FACE)
    activate(self._shader_opaque)

    setUniform!(self._shader_opaque,"VP",vp)
    setUniform!(self._shader_opaque,"lightDirCam",-cam_light)
    setUniform!(self._shader_opaque,"lightDirSide",-side_light)
    @time_gpu_begin Dependent TriangleCluster OPAQUE_PASS
    draw(self._buffer_opaque,GL_TRIANGLES)
    @time_gpu_end Dependent TriangleCluster OPAQUE_PASS

    glEnable(GL_CULL_FACE)
    return nothing
end

function transparent_pass!(self::TriangleClusterRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    if length(self._buffer_transparent) == 0 return nothing end
    (cam_light, side_light) = get_lights(cam)
    glDisable(GL_CULL_FACE)
    activate(self._shader_transparent)
    
    setUniform!(self._shader_transparent,"VP",vp)
    setUniform!(self._shader_transparent,"lightDirCam",-cam_light)
    setUniform!(self._shader_transparent,"lightDirSide",-side_light)
    @time_gpu_begin Dependent TriangleCluster OPAQUE_PASS
    draw(self._buffer_transparent,GL_TRIANGLES)
    @time_gpu_end Dependent TriangleCluster OPAQUE_PASS

    glEnable(GL_CULL_FACE)
    return nothing
end

# ! Must have
function destroy!(self::TriangleClusterRenderer)
    destroy!(self._shader_id)
    destroy!(self._shader_opaque)
    destroy!(self._buffer_transparent)
    destroy!(self._buffer_opaque)
    destroy!(self._buffer_transparent)
end

# ! Must have
function Plan2Observer(self::OpenGLData,plan::TriangleClusterPlan)
    return SingleRendererTactic(self,_TRIANGLE_CLUSTER_RENDERER,TriangleClusterRenderer)::TriangleClusterRenderer
end