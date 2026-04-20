# GREEN Thread

mutable struct SphereRenderer
    shader_opaque::ShaderProgram
    shader_transparent::ShaderProgram

    center_radius_opaque::Vector{Vec4F}
    color_id_opaque::Vector{Vec2T{UInt32}}
    center_radius_transparent::Vector{Vec4F}
    color_id_transparent::Vector{Vec2T{UInt32}}

    center_radius_buffer_opaque::MappedBuffer{Vec4F}
    color_id_buffer_opaque::Buffer{Vec2T{UInt32}}
    center_radius_buffer_transparent::MappedBuffer{Vec4F}
    color_id_buffer_transparent::Buffer{Vec2T{UInt32}}

    updated_opaque::Bool
    updated_transparent::Bool
    
    function SphereRenderer()
        uniforms_opaque = String["fov"]
        shader_opaque = ShaderProgram(["renderers/sphere/sphere.vert","renderers/sphere/sphere.frag"], uniforms_opaque)
        uniforms_transparent = String["fov","near"]
        shader_transparent = ShaderProgram(["renderers/sphere/sphere.vert",(("renderers/sphere/sphere_transparent.frag",["TRANSPARENT"]))], uniforms_transparent)
        return new(
            shader_opaque, shader_transparent,
            Vector{Vec4F}(), Vector{Vec2T{UInt32}}(), Vector{Vec4F}(), Vector{Vec2T{UInt32}}(),
            MappedBuffer{Vec4F}(), Buffer{Vec2T{UInt32}}(), MappedBuffer{Vec4F}(), Buffer{Vec2T{UInt32}}(),
            false, false
        )
    end
end

function destroy!(self::SphereRenderer)::Nothing
    destroy!(self.shader_opaque)
    destroy!(self.shader_transparent)
    destroy!(self.center_radius_buffer_opaque)
    destroy!(self.color_id_buffer_opaque)
    destroy!(self.center_radius_buffer_transparent)
    destroy!(self.color_id_buffer_transparent)
    return nothing
end

function add!(self::SphereRenderer,coord::Vec3F,radius::Float32,color::Vec4F,id::UInt32)::UInt32
    if (color[4] == 1.0f0)
        push!(self.center_radius_opaque, Vec4F(coord[1],coord[2],coord[3],radius))
        push!(self.color_id_opaque, Vec2T{UInt32}(packUnorm4x8(color),id))
        return UInt32(length(self.center_radius_opaque))
    else
        push!(self.center_radius_transparent, Vec4F(coord[1],coord[2],coord[3],radius))
        push!(self.color_id_transparent, Vec2T{UInt32}(packUnorm4x8(color),id))
        return UInt32(length(self.center_radius_transparent))
    end
end

function added_all!(self::SphereRenderer)::Nothing
    if length(self.center_radius_opaque) != length(self.center_radius_buffer_opaque)
        upload!(self.center_radius_buffer_opaque,self.center_radius_opaque,0)
        upload!(self.color_id_buffer_opaque,self.color_id_opaque,0)
        self.updated_opaque = false
    end
    if length(self.center_radius_transparent) != length(self.center_radius_buffer_transparent)
        upload!(self.center_radius_buffer_transparent,self.center_radius_transparent,0)
        upload!(self.color_id_buffer_transparent,self.color_id_transparent,0)
        self.updated_transparent = false
    end
    return nothing
end

function update_coord_radius!(self::SphereRenderer,ref::UInt32,coord::Vec3F,radius::Float32,alpha::Float32)
    if alpha == 1.0f0
        self.center_radius_opaque[ref] = Vec4F(coord[1],coord[2],coord[3],radius)
        self.updated_opaque = true
    else
        self.center_radius_transparent[ref] = Vec4F(coord[1],coord[2],coord[3],radius)
        self.updated_transparent = true
    end
end

function sync_all!(self::SphereRenderer)::Nothing
    if self.updated_opaque
        wait(self.center_radius_buffer_opaque)
        copyto!(self.center_radius_buffer_opaque,self.center_radius_opaque)
        self.updated_opaque = false
    end
    if self.updated_transparent
        wait(self.center_radius_buffer_transparent)
        copyto!(self.center_radius_buffer_transparent,self.center_radius_transparent)
        self.updated_transparent = false
    end
    return nothing
end

function opaque(self::SphereRenderer,cam::Camera,shrd::SharedData)::Nothing
    if isempty(self.center_radius_opaque) return nothing end

    glDisable(GL_CULL_FACE)
    
    activate(self.shader_opaque)

    bind_ssbo(self.center_radius_buffer_opaque,0)
    bind_ssbo(self.color_id_buffer_opaque,1)

    uniform(self.shader_opaque,"fov",deg2rad(cam._fov))

    @time_gpu_begin Renderer Sphere Opaque
    glDrawArrays(GL_TRIANGLES,0,length(self.center_radius_opaque) * 6)
    @time_gpu_end Renderer Sphere Opaque
    lock(self.center_radius_buffer_opaque)

    glEnable(GL_CULL_FACE)
    return nothing
end

function transparent(self::SphereRenderer,cam::Camera,shrd::SharedData)::Nothing
    if isempty(self.center_radius_transparent) return nothing end

    activate(self.shader_transparent)

    bind_ssbo(self.center_radius_buffer_transparent,0)
    bind_ssbo(self.color_id_buffer_transparent,1)

    uniform(self.shader_transparent,"fov",deg2rad(cam._fov))

    @time_gpu_begin Renderer Sphere Transparent
    uniform(self.shader_transparent,"near",1.0f0)
    glDrawArrays(GL_TRIANGLES,0,length(self.center_radius_transparent) * 6)
    uniform(self.shader_transparent,"near",-1.0f0)
    glDrawArrays(GL_TRIANGLES,0,length(self.center_radius_transparent) * 6)
    @time_gpu_end Renderer Sphere Transparent
    lock(self.center_radius_buffer_transparent)

    return nothing
end