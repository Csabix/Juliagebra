# GREEN Thread

mutable struct SphereRenderer
    shader_opaque::ShaderProgram
    shader_transparent::ShaderProgram

    center_radius::Vector{Vec4F}
    color_id::Vector{Vec2T{UInt32}}

    center_radius_buffer::MappedBuffer{Vec4F}
    color_id_buffer::Buffer{Vec2T{UInt32}}

    updated::Bool
    
    function SphereRenderer()
        uniforms = String["VP","cam","at","lightDirCam","lightDirSide","ASPECT_FOV_RESOLUTION"]
        shader_opaque = ShaderProgram(["renderers/sphere/sphere.vert","renderers/sphere/sphere.frag"], uniforms)
        shader_transparent = ShaderProgram(["renderers/sphere/sphere.vert","renderers/sphere/sphere.frag"], uniforms)
        return new(
            shader_opaque, shader_transparent,
            Vector{Vec4F}(), Vector{Vec2T{UInt32}}(),
            MappedBuffer{Vec4F}(),Buffer{Vec2T{UInt32}}(),
            false
        )
    end
end

function destroy!(self::SphereRenderer)::Nothing
    destroy!(self.shader_opaque)
    destroy!(self.shader_transparent)
    destroy!(self.center_radius_buffer)
    destroy!(self.color_id_buffer)
    return nothing
end

function add!(self::SphereRenderer,coord::Vec3F,radius::Float32,color::Vec4F,id::UInt32)::UInt32
    push!(self.center_radius, Vec4F(coord[1],coord[2],coord[3],radius))
    push!(self.color_id, Vec2T{UInt32}(packUnorm4x8(color),id))
    return UInt32(length(self.center_radius))
end

function added_all!(self::SphereRenderer)::Nothing
    if length(self.center_radius) != length(self.center_radius_buffer)
        upload!(self.center_radius_buffer,self.center_radius,0)
        upload!(self.color_id_buffer,self.color_id,0)
        self.updated = false
    end
    return nothing
end

function update_coord_radius!(self::SphereRenderer,ref::UInt32,coord::Vec3F,radius::Float32)
    self.center_radius[ref] = Vec4F(coord[1],coord[2],coord[3],radius)
    self.updated = true
end

function sync_all!(self::SphereRenderer)::Nothing
    if self.updated
        wait(self.center_radius_buffer)
        copyto!(self.center_radius_buffer,self.center_radius)
        self.updated = false
    end
    return nothing
end

function opaque(self::SphereRenderer,cam::Camera,shrd::SharedData)::Nothing
    if isempty(self.center_radius) return nothing end
    (vp, _, _) = get_matrices(cam)
    (cam_light, side_light) = get_lights(cam)

    glDisable(GL_CULL_FACE)
    
    activate(self.shader_opaque)

    bind_ssbo(self.center_radius_buffer,0)
    bind_ssbo(self.color_id_buffer,1)

    uniform(self.shader_opaque,"lightDirCam",-cam_light)
    uniform(self.shader_opaque,"lightDirSide",-side_light)
    uniform(self.shader_opaque,"VP",vp)
    uniform(self.shader_opaque,"cam",cam._eye)
    uniform(self.shader_opaque,"at",cam._at)
    uniform(self.shader_opaque,"ASPECT_FOV_RESOLUTION",
        Vec4F(Float32(shrd._width)/Float32(shrd._height),deg2rad(cam._fov),Float32(shrd._width),Float32(shrd._height)))

    @time_gpu_begin Renderer Sphere Opaque
    glDrawArrays(GL_TRIANGLES,0,length(self.center_radius) * 6)
    @time_gpu_end Renderer Sphere Opaque
    lock(self.center_radius_buffer)

    glEnable(GL_CULL_FACE)
    return nothing
end