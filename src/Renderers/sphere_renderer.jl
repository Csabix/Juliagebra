# GREEN Thread

mutable struct SphereRenderer <: Renderer
    shader_opaque::Pipeline
    shader_transparent_front::Pipeline
    shader_transparent_back::Pipeline

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
    
    function SphereRenderer(loader::PipelineLoader)
        shader_opaque = create_graphics_pipeline!(loader;
            vert = spv"renderers/sphere/sphere.vert",
            frag = spv"renderers/sphere/sphere.frag"
        )
        
        shader_transparent_front = create_graphics_pipeline!(loader;
            vert = (spv"renderers/sphere/sphere.vert",Tuple{GLuint,GLuint}[(0,reinterpret(GLuint,Float32(0.0)))]),
            frag = (spv"renderers/sphere/sphere_transparent.frag",Tuple{GLuint,GLuint}[(0,reinterpret(GLuint,Float32(1.0)))])
        )

        shader_transparent_back = create_graphics_pipeline!(loader;
            vert = spv"renderers/sphere/sphere.vert",
            frag = (spv"renderers/sphere/sphere_transparent.frag",Tuple{GLuint,GLuint}[(0,reinterpret(GLuint,Float32(-1.0)))])
        )

        return new(
            shader_opaque, shader_transparent_front, shader_transparent_back,
            Vector{Vec4F}(), Vector{Vec2T{UInt32}}(), Vector{Vec4F}(), Vector{Vec2T{UInt32}}(),
            MappedBuffer{Vec4F}(), Buffer{Vec2T{UInt32}}(), MappedBuffer{Vec4F}(), Buffer{Vec2T{UInt32}}(),
            false, false
        )
    end
end

function clear!(self::SphereRenderer)::Nothing
    destroy!(self.center_radius_buffer_opaque)
    destroy!(self.color_id_buffer_opaque)
    destroy!(self.center_radius_buffer_transparent)
    destroy!(self.color_id_buffer_transparent)

    self.center_radius_opaque = Vector{Vec4F}()
    self.color_id_opaque = Vector{Vec2T{UInt32}}()
    self.center_radius_transparent = Vector{Vec4F}()
    self.color_id_transparent = Vector{Vec2T{UInt32}}()

    self.center_radius_buffer_opaque = MappedBuffer{Vec4F}()
    self.color_id_buffer_opaque = Buffer{Vec2T{UInt32}}()
    self.center_radius_buffer_transparent = MappedBuffer{Vec4F}()
    self.color_id_buffer_transparent = Buffer{Vec2T{UInt32}}()

    self.updated_opaque = false
    self.updated_transparent = false
    return nothing
end

function destroy!(self::SphereRenderer)::Nothing
    destroy!(self.center_radius_buffer_opaque)
    destroy!(self.color_id_buffer_opaque)
    destroy!(self.center_radius_buffer_transparent)
    destroy!(self.color_id_buffer_transparent)
    return nothing
end

function add!(self::SphereRenderer,coord::Vec3F,radius::Float32,color::UInt32,id::UInt32)::UInt32
    if is_packed_opaque(color)
        push!(self.center_radius_opaque, Vec4F(coord[1],coord[2],coord[3],radius))
        push!(self.color_id_opaque, Vec2T{UInt32}(color,id))
        return UInt32(length(self.center_radius_opaque))
    else
        push!(self.center_radius_transparent, Vec4F(coord[1],coord[2],coord[3],radius))
        push!(self.color_id_transparent, Vec2T{UInt32}(color,id))
        return UInt32(length(self.center_radius_transparent))
    end
end

function update_coord_radius!(self::SphereRenderer,ref::UInt32,coord::Vec3F,radius::Float32,color::UInt32)
    if is_packed_opaque(color)
        self.center_radius_opaque[ref] = Vec4F(coord[1],coord[2],coord[3],radius)
        self.updated_opaque = true
    else
        self.center_radius_transparent[ref] = Vec4F(coord[1],coord[2],coord[3],radius)
        self.updated_transparent = true
    end
end

function pre_draw!(self::SphereRenderer,cam::Camera,window::GLFWData)::Nothing
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

function draw_opaque!(self::SphereRenderer,cam::Camera,window::GLFWData)::Nothing
    if isempty(self.center_radius_opaque) return nothing end

    glDisable(GL_CULL_FACE)
    
    activate(self.shader_opaque)

    bind_ssbo(self.center_radius_buffer_opaque,0)
    bind_ssbo(self.color_id_buffer_opaque,1)

    @time_gpu_begin Renderer Sphere Opaque
    glDrawArrays(GL_TRIANGLES,0,length(self.center_radius_opaque) * 6)
    @time_gpu_end Renderer Sphere Opaque
    lock(self.center_radius_buffer_opaque)

    glEnable(GL_CULL_FACE)
    return nothing
end

function draw_transparent!(self::SphereRenderer,cam::Camera,window::GLFWData)::Nothing
    if isempty(self.center_radius_transparent) return nothing end
    
    bind_ssbo(self.center_radius_buffer_transparent,0)
    bind_ssbo(self.color_id_buffer_transparent,1)

    @time_gpu_begin Renderer Sphere Transparent
    activate(self.shader_transparent_front)
    glDrawArrays(GL_TRIANGLES,0,length(self.center_radius_transparent) * 6)
    activate(self.shader_transparent_back)
    glDrawArrays(GL_TRIANGLES,0,length(self.center_radius_transparent) * 6)
    @time_gpu_end Renderer Sphere Transparent
    lock(self.center_radius_buffer_transparent)

    return nothing
end