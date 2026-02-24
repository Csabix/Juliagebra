#=
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
        _mesh = Mesh(
            collect(get_positions_it(mesh)),
            collect(get_indices_it(mesh))
        )
        new(RenderedPlan(callback,plans),_mesh,transform,color,transparent)
    end
end

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

function _get_positions(self::TriangleClusterDependent)
    return isnothing(self._mesh.indices) ? [Vec4F(pos...,1) for pos in self._mesh.positions] : [Vec4F(self._mesh.positions[index]...,1) for index in self._mesh.indices]
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
    _draw_range_opaque::Vector{Tuple{Cuint,Cuint}}
    _matrices_opaque::Mat4T{Float32}

    _positions_transparent::Vector{Vec3F}
    _colors_transparent::Vector{Vec3F}
    _draw_range_transparent::Vector{Tuple{Cuint,Cuint}}


    function TriangleClusterRenderer(context::OpenGLData)
        renderer = Renderer{TriangleClusterDependent}(context)

        id = ShaderProgram(sp("surface/surface_id.vert"),sp("surface/surface_id.frag"),["VP"])
        opaque = ShaderProgram(sp("surface/surface.vert"),sp("surface/surface_opaque.frag"),["VP","lightDirCam","lightDirSide"])
        transparent = ShaderProgram(sp("surface/surface.vert"),sp(".surface/surface_transparent.frag"),["VP","lightDirCam","lightDirSide"])

        new(renderer,
            id,opaque,transparent,
            IndexedTypedBufferArray{Tuple{Vec4F,Vec4F,Vec3F}}(),IndexedTypedBufferArray{Tuple{Vec4F,Vec4F,Vec3F}}(),
            Vector{Vec3F}(),Vector{Vec3F}(),
            Vector{Vec3F}(),Vector{Vec3F}(),
            Vector{SubArray{Vec3F}}())
    end
end

_Renderer_(self::TriangleClusterRenderer) = return self._renderer
Base.string(self::TriangleClusterRenderer) = return "Triangle cluster renderer"

function added!(self::TriangleClusterRenderer,cluster::TriangleClusterDependent)
    dst_positions  = cluster._transparent ? self._positions_transparent  : self._positions_opaque
    dst_colors     = cluster._transparent ? self._colors_transparent     : self._colors_opaque
    dst_draw_range = cluster._transparent ? self._draw_range_transparent : self._draw_range_opaque

    base_index::UInt32 = length(dst_positions)
    it = get_positions_it(cluster._mesh)
    len = length(it)
    
    append!(dst_positions,it)
    push!(dst_colors,cluster._color)
    
    push!(self._views,view(dst_positions,base_index:base_index+len-1))
    push!(dst_draw_range,(Cuint(base_index-1),Cuint(len)))
end

setRenderedID!(renderer::TriangleClusterRenderer,dependent::TriangleClusterDependent,id) = return nothing

function addedAll!(self::TriangleClusterRenderer)
    #upload!(self._buffer_opaque,1,self._positions_opaque,GL_STATIC_DRAW)
    #upload!(self._buffer_opaque,2,self._normals_opaque,GL_STATIC_DRAW)
    #upload!(self._buffer_opaque,3,self._colors_opaque,GL_STATIC_DRAW)
    #uploadIndexes!(self._buffer_opaque,self._indices_opaque,GL_STATIC_DRAW)

    #upload!(self._buffer_transparent,1,self._positions_transparent,GL_STATIC_DRAW)
    #upload!(self._buffer_transparent,2,self._normals_transparent,GL_STATIC_DRAW)
    #upload!(self._buffer_transparent,3,self._colors_transparent,GL_STATIC_DRAW)
    #uploadIndexes!(self._buffer_transparent,self._indices_transparent,GL_STATIC_DRAW)
end

function sync!(self::TriangleClusterRenderer,curve::TriangleClusterDependent)
end


function syncAll!(self::TriangleClusterRenderer)
end

=#

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
        _mesh = Mesh(
            collect(get_positions_it(mesh)),
            collect(get_indices_it(mesh))
        )
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

evalCallbackDpReturn(self::TriangleClusterDependent,v) = begin end
evalCallbackDpReturn(self::TriangleClusterDependent,v::Vec3D) = begin end
evalCallbackDpReturn(self::TriangleClusterDependent,v::Vec3F) = begin end
evalCallbackDpReturn(self::TriangleClusterDependent,v::Nothing) = begin end

function _get_positions(self::TriangleClusterDependent)
    return isnothing(self._mesh.indices) ? [Vec4F(pos...,1) for pos in self._mesh.positions] : [Vec4F(self._mesh.positions[index+1]...,1) for index in self._mesh.indices]
end

# ? ---------------------------------
# ! TriangleClusterRenderer
# ? ---------------------------------

mutable struct DynamicTriangleClusterRenderer <: RendererDNA{TriangleClusterDependent}
    _renderer::Renderer{TriangleClusterDependent}

    _shader_calc_normals::ShaderProgram
    _shader_id::ShaderProgram
    _shader_opaque::ShaderProgram
    _shader_transparent::ShaderProgram

    _buffers_opaque::Vector{TypedBufferArray}
    _matrices_opaque::Vector{Mat4T{Float32}}

    _buffers_transparent::Vector{TypedBufferArray}
    _matrices_transparent::Vector{Mat4T{Float32}}


    function DynamicTriangleClusterRenderer(context::OpenGLData)
        renderer = Renderer{TriangleClusterDependent}(context)

        id = ShaderProgram(sp("surface/surface_id.vert"),sp("surface/surface_id.frag"),["VP"])
        opaque = ShaderProgram(sp("surface/surface.vert"),sp("surface/surface_opaque.frag"),["VP","lightDirCam","lightDirSide"])
        transparent = ShaderProgram(sp("surface/surface.vert"),sp("surface/surface_transparent.frag"),["VP","lightDirCam","lightDirSide"])
        calc_normals = ShaderProgram(sp("calc_normals.comp"))

        new(renderer,
            calc_normals,id,opaque,transparent,
            Vector{TypedBufferArray{Tuple{Vec3F,Vec3F,Vec3F}}}(),Vector{Mat4T{Float32}}(),
            Vector{TypedBufferArray{Tuple{Vec3F,Vec3F,Vec3F}}}(),Vector{Mat4T{Float32}}())
    end
end

_Renderer_(self::DynamicTriangleClusterRenderer) = return self._renderer
Base.string(self::DynamicTriangleClusterRenderer) = return "Triangle cluster renderer"

function added!(self::DynamicTriangleClusterRenderer,cluster::TriangleClusterDependent)
    dst_buffers  = cluster._transparent ? self._buffers_transparent  : self._buffers_opaque
    dst_matrices = cluster._transparent ? self._matrices_transparent : self._matrices_opaque
    
    buffer = TypedBufferArray{Tuple{Vec4F,Vec4F,Vec3F}}()
    positions = _get_positions(cluster)
    upload!(buffer,1,positions,GL_DYNAMIC_DRAW)
    reserve!(buffer,2,length(positions),GL_STATIC_DRAW)
    upload!(buffer,3,fill(color,length(positions)),GL_STATIC_DRAW)

    push!(dst_buffers,buffer)
    push!(dst_matrices,cluster._transform)

    activate(self._shader_calc_normals)
    bind_ssbo!(buffer,1,0)
    bind_ssbo!(buffer,2,1)
    glDispatchCompute(cld(length(positions),64),1,1);
end

function addedAll!(self::DynamicTriangleClusterRenderer)
    glMemoryBarrier(GL_VERTEX_ATTRIB_ARRAY_BARRIER_BIT)
end

function sync!(self::DynamicTriangleClusterRenderer,curve::TriangleClusterDependent)
end

syncAll!(self::DynamicTriangleClusterRenderer) = return nothing

function id_pass!(self::DynamicTriangleClusterRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    glDisable(GL_CULL_FACE)
    
    activate(self._shader_id)
    for i in 1:length(self._buffers_opaque)
        setUniform!(self._shader_id,"VP",vp*self._matrices_opaque[i])
        if length(self._buffers_opaque[i]) != 0 draw(self._buffers_opaque[i],GL_TRIANGLES) end
    end

    glEnable(GL_CULL_FACE)
    return nothing
end

function opaque_pass!(self::DynamicTriangleClusterRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    if length(self._buffers_opaque) == 0 return nothing end
    (cam_light, side_light) = get_lights(cam)
    glDisable(GL_CULL_FACE)
    
    activate(self._shader_opaque)
    setUniform!(self._shader_opaque,"lightDirCam",-cam_light)
    setUniform!(self._shader_opaque,"lightDirSide",-side_light)
    for i in 1:length(self._buffers_opaque)
        setUniform!(self._shader_opaque,"VP",vp*self._matrices_opaque[i])
        if length(self._buffers_opaque[i]) != 0 draw(self._buffers_opaque[i],GL_TRIANGLES) end
    end

    glEnable(GL_CULL_FACE)
    return nothing
end

function transparent_pass!(self::DynamicTriangleClusterRenderer,vp::Mat4T{Float32},cam::Camera,shrd::SharedData)::Nothing
    if length(self._buffers_transparent) == 0 return nothing end
    (cam_light, side_light) = get_lights(cam)
    glDisable(GL_CULL_FACE)
    
    activate(self._shader_transparent)
    setUniform!(self._shader_transparent,"lightDirCam",-cam_light)
    setUniform!(self._shader_transparent,"lightDirSide",-side_light)
    for i in 1:length(self._buffers_transparent)
        setUniform!(self._shader_transparent,"VP",vp*self._matrices_transparent[i])
        if length(self._buffers_transparent[i]) != 0 draw(self._buffers_transparent[i],GL_TRIANGLES) end
    end

    glEnable(GL_CULL_FACE)
    return nothing
end

function destroy!(self::DynamicTriangleClusterRenderer)
    destroy!(self._shader_id)
    destroy!(self._shader_opaque)
    destroy!(self._shader_transparent)
    destroy!.(self._buffers_opaque)
    destroy!.(self._buffers_transparent)
end

function Plan2Observer(self::OpenGLData,plan::TriangleClusterPlan)
    return SingleRendererTactic(self,_TRIANGLE_CLUSTER_RENDERER,DynamicTriangleClusterRenderer)::DynamicTriangleClusterRenderer
end