const _SPHERE_NONE::UInt32 = 0x0
const _SPHERE_CENTER_RADIUS::UInt32 = 0x1
const _SPHERE_COLOR::UInt32 = 0x2

mutable struct SphereRenderer
    shader_opaque::Pipeline
    shader_transparent_front::Pipeline
    shader_transparent_back::Pipeline

    center_radius::Vector{Vec4F}
    color::Vector{UInt32}
    id::Vector{UInt32}

    center_radius_buffer::MappedBuffer{Vec4F}
    color_buffer::Buffer{UInt32}
    id_buffer::Buffer{UInt32}

    change::UInt32

    function SphereRenderer(loader::PipelineLoader)
        shader_opaque = create_graphics_pipeline!(loader;
            vert = spv"renderers/sphere/sphere.vert",
            frag = spv"renderers/sphere/sphere.frag"
        )
        
        shader_transparent_front = create_graphics_pipeline!(loader;
            vert = (spv"renderers/sphere/sphere.vert",Tuple{GLuint,GLuint}[(0,reinterpret(GLuint,Float32(0.0))),(1,GLuint(0))]),
            frag = (spv"renderers/sphere/sphere_transparent.frag",Tuple{GLuint,GLuint}[(0,reinterpret(GLuint,Float32(1.0)))])
        )

        shader_transparent_back = create_graphics_pipeline!(loader;
            vert = (spv"renderers/sphere/sphere.vert",Tuple{GLuint,GLuint}[(1,GLuint(0))]),
            frag = (spv"renderers/sphere/sphere_transparent.frag",Tuple{GLuint,GLuint}[(0,reinterpret(GLuint,Float32(-1.0)))])
        )

        return new(
            shader_opaque, shader_transparent_front, shader_transparent_back,
            Vector{Vec4F}(), Vector{UInt32}(),Vector{UInt32}(),
            MappedBuffer{Vec4F}(), Buffer{UInt32}(),Buffer{UInt32}(),
            _SPHERE_NONE
        )
    end
end

function reset!(self::SphereRenderer)::Nothing
    destroy!(self.center_radius_buffer)
    destroy!(self.color_buffer)
    destroy!(self.id_buffer)
    self.center_radius_buffer = MappedBuffer{Vec4F}()
    self.color_buffer = Buffer{UInt32}()
    self.id_buffer = Buffer{UInt32}()

    self.center_radius = Vector{Vec4F}()
    self.color = Vector{UInt32}()
    self.id = Vector{UInt32}()
    return nothing
end

function destroy!(self::SphereRenderer)::Nothing
    destroy!(self.center_radius_buffer)
    destroy!(self.color_buffer)
    destroy!(self.id_buffer)
    return nothing
end

function add!(self::SphereRenderer,coord::Vec3F,radius::Float32,color::UInt32,id::UInt32)::UInt32
    push!(self.center_radius, Vec4F(coord[1],coord[2],coord[3],radius))
    push!(self.color, color)
    push!(self.id, id)
    return UInt32(length(self.center_radius))
end

function added_all!(self::SphereRenderer)::Nothing
    if length(self.center_radius) != length(self.center_radius_buffer)
        upload!(self.center_radius_buffer,self.center_radius,0)
        upload!(self.color_buffer,self.color,0)
        upload!(self.id_buffer,self.id,0)
    end
    return nothing
end

function update_coord!(self::SphereRenderer,ref::UInt32,coord::Vec3F)::Nothing
    radius = self.center_radius[ref][4]
    self.center_radius[ref] = Vec4F(coord[1],coord[2],coord[3],radius)
    self.change |= _SPHERE_CENTER_RADIUS
    return nothing
end
function update_radius!(self::SphereRenderer,ref::UInt32,radius::Float32)::Nothing
    coord = self.center_radius[ref]
    self.center_radius[ref] = Vec4F(coord[1],coord[2],coord[3],radius)
    self.change |= _SPHERE_CENTER_RADIUS
    return nothing
end
function update_coord_radius!(self::SphereRenderer,ref::UInt32,coord::Vec3F,radius::Float32)::Nothing
    self.center_radius[ref] = Vec4F(coord[1],coord[2],coord[3],radius)
    self.change |= _SPHERE_CENTER_RADIUS
    return nothing
end
function update_color!(self::SphereRenderer, ref::UInt32, color::UInt32)::Nothing
    self.color[ref] = color
    self.change |= _SPHERE_COLOR
    return nothing
end

function sync_all!(self::SphereRenderer)::Bool
    scene_change::Bool = false
    if (self.change & _SPHERE_CENTER_RADIUS) == _SPHERE_CENTER_RADIUS
        wait(self.center_radius_buffer)
        copyto!(self.center_radius_buffer,self.center_radius)
        scene_change = true
    end
    if (self.change & _SPHERE_COLOR) == _SPHERE_COLOR
        upload!(self.color_buffer,self.color,0)
        scene_change = true
    end
    self.change = _SPHERE_NONE
    return scene_change
end

function opaque(self::SphereRenderer,cam::Camera,window::GLFWData)::Nothing
    if isempty(self.center_radius) return nothing end

    glDisable(GL_CULL_FACE)
    
    activate(self.shader_opaque)

    bind_ssbo(self.center_radius_buffer,0)
    bind_ssbo(self.color_buffer,1)
    bind_ssbo(self.id_buffer,2)

    @time_gpu_begin Renderer Sphere Opaque
    glDrawArrays(GL_TRIANGLES,0,length(self.center_radius) * 6)
    @time_gpu_end Renderer Sphere Opaque
    lock(self.center_radius_buffer)

    glEnable(GL_CULL_FACE)
    return nothing
end

function transparent(self::SphereRenderer,cam::Camera,window::GLFWData)::Nothing
    if isempty(self.center_radius) return nothing end
    
    bind_ssbo(self.center_radius_buffer,0)
    bind_ssbo(self.color_buffer,1)
    bind_ssbo(self.id_buffer,2)

    @time_gpu_begin Renderer Sphere Transparent
    activate(self.shader_transparent_front)
    glDrawArrays(GL_TRIANGLES,0,length(self.center_radius) * 6)
    activate(self.shader_transparent_back)
    glDrawArrays(GL_TRIANGLES,0,length(self.center_radius) * 6)
    @time_gpu_end Renderer Sphere Transparent
    lock(self.center_radius_buffer)

    return nothing
end