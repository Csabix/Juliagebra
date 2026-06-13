
# ? ---------------------------------
# ! OpenGLData
# ? ---------------------------------

function debug_callback(source::GLenum, typ::GLenum, id::GLuint, severity::GLenum, 
                        len::GLsizei, message::Ptr{GLchar}, userParam::Ptr{Cvoid})::Nothing
    if glGetError() != 0
        msg = unsafe_string(message, len)
        println("---------------------")
        println("OpenGL Debug Message:")
        println("Message: ", msg)
        println("Source:  ", source)
        println("Type:    ", typ)
        println("ID:      ", id)
        println("Severity:", severity)
        error()
    end
    return nothing
end

struct UBO_Data
    VP::Mat4T{Float32}
    V::Mat4T{Float32}
    P::Mat4T{Float32}
    _light_side_width::Vec4F
    _light_cam_heigth::Vec4F
    _eye_aspect::Vec4F
    _at_width_u::Vec4F
    _near_far_fov_unused::Vec4F
end

mutable struct OpenGLData
    _profiler::Profiler
    _passes::@NamedTuple{pre_draw::UInt32, widgets::UInt32, opaque::UInt32, behind_opaque::UInt32, transparent::UInt32, post_process::UInt32}
    _cpu_stopwatch::UInt32
    _shrd::SharedData
    _pipeline_loader::PipelineLoader

    _observers::Vector{RendererDNA}
    _renderers::PrimitiveRenderers

    # ! Shaders
    _transparent_color_combiner::Pipeline
    _transparent_id_combiner::Pipeline
    _highlighter::Pipeline
    _buffer_clear::Pipeline
    _grid::Pipeline

    # ! Main FBO objects
    _rgbaTexture::Texture2D
    _idTexture::Texture2D
    _depthstencilTexture::Texture2D
    _behindOpaqueDepthstencilTexture::Texture2D
    _accumTexture::Texture2D
    _revealTexture::Texture2D

    _opaqueFBO::FrameBuffer
    _behindOpaqueFBO::FrameBuffer
    _transparentFBO::FrameBuffer

    _ubo::MappedBuffer{UBO_Data}
    _pixel_buffer::Buffer{UVec2}
    
    _empty_VAO::VertexArray

    _gizmoGL::GizmoGL
    _orthoGizmoGL::OrthoGizmoGL

    _backgroundCol::Vec3F

    _vp::Mat4T{Float32}
    _v::Mat4T{Float32}
    _p::Mat4T{Float32}
    _camPos::Vec3F

    # GREEN Thread, runs this inside Init, after this construction can begin
    function OpenGLData(window::GLFWData,shrd::SharedData,asset_watcher::Union{Nothing,AssetWatcher})
        c_debug_callback = @cfunction(debug_callback, Nothing, 
                                 (GLenum, GLenum, GLuint, GLenum, GLsizei, Ptr{GLchar}, Ptr{Cvoid}))
        glEnable(GL_DEBUG_OUTPUT)
        glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS)
        glDebugMessageCallback(c_debug_callback, C_NULL)

        # ! for OpenGLData to succesfully construct, a GLFWData is required, but not stored
        glClearStencil(0)
        glStencilMask(0xFF);
        glClearColor(0.73f0,0.73f0,0.73f0,1.0f0)
        glDisable(GL_DITHER);

        profiler = Profiler()
        passes = (
            pre_draw      = add_gpu_stopwatch(profiler),
            widgets       = add_gpu_stopwatch(profiler),
            opaque        = add_gpu_stopwatch(profiler),
            behind_opaque = add_gpu_stopwatch(profiler),
            transparent   = add_gpu_stopwatch(profiler),
            post_process  = add_gpu_stopwatch(profiler)
        )
        cpu_stopwatch = add_cpu_stopwatch(profiler)
        init!(profiler)
        
        pipeline_loader = PipelineLoader()
        full_compile(pipeline_loader)
        if haskey(ENV,"JULIAGEBRA_COMPILE_SPIRV") && ENV["JULIAGEBRA_COMPILE_SPIRV"] == "true"
            if asset_watcher !== nothing
                watch_folder!(asset_watcher,pkgdir(@__MODULE__,"assets","shaders","src"))
                set_file_changed_callback(asset_watcher,glsl_shader_extensions,get_glsl_update_callback(pipeline_loader))
                set_file_deleted_callback(asset_watcher,glsl_shader_extensions,get_glsl_delete_callback(pipeline_loader))
                set_file_changed_callback(asset_watcher,glsl_shader_include_extensions,get_glsl_include_update_callback(pipeline_loader))
            end
        end

        gizmoGL = GizmoGL(pipeline_loader,window._scale)
        orthoGizmoGL = OrthoGizmoGL(pipeline_loader,window._scale)

        transparent_color_combiner = create_graphics_pipeline!(pipeline_loader;
            vert = spv"renderers/fullscreen.vert",
            frag = spv"renderers/transparent_color.frag"
        )
        transparent_id_combiner = create_graphics_pipeline!(pipeline_loader;
            vert = spv"renderers/fullscreen.vert",
            frag = spv"renderers/transparent_id.frag"
        )
        highlighter = create_graphics_pipeline!(pipeline_loader;
            vert = spv"postprocess/highlight.vert",
            frag = spv"postprocess/highlight.frag"
        )
        buffer_clear = create_compute_pipeline!(pipeline_loader,spv"renderers/buffer_clear.comp")
        grid = create_graphics_pipeline!(pipeline_loader;
            vert = spv"postprocess/grid.vert",
            frag = spv"postprocess/grid.frag"
        )

        depth_stencil = Texture2D(shrd._width,shrd._height,GL_DEPTH24_STENCIL8,GL_DEPTH_STENCIL,GL_UNSIGNED_INT_24_8)
        depth_stencil_behind_opaque = Texture2D(shrd._width,shrd._height,GL_DEPTH24_STENCIL8,GL_DEPTH_STENCIL,GL_UNSIGNED_INT_24_8)
        id = createIDTexture2D(shrd._width,shrd._height)
        rgba = Texture2D(shrd._width,shrd._height,GL_RGBA8,GL_RGBA,GL_UNSIGNED_BYTE)
        accum = Texture2D(shrd._width,shrd._height,GL_RGBA16F,GL_RGBA,GL_HALF_FLOAT)
        reveal = Texture2D(shrd._width,shrd._height,GL_R8,GL_RED,GL_FLOAT)

        opaqueAttachements = (
            (GL_COLOR_ATTACHMENT0, rgba),
            (GL_COLOR_ATTACHMENT1, id),
            (GL_DEPTH_STENCIL_ATTACHMENT, depth_stencil)
        )
        opaqueFBO = FrameBuffer(opaqueAttachements)

        behindOpaqueAttachements = (
            (GL_COLOR_ATTACHMENT0,rgba),
            (GL_COLOR_ATTACHMENT1,id),
            (GL_DEPTH_STENCIL_ATTACHMENT,depth_stencil_behind_opaque)
        )
        behindOpaqueFBO = FrameBuffer(behindOpaqueAttachements)

        transparentAttachments = (
            (GL_COLOR_ATTACHMENT0,accum),
            (GL_COLOR_ATTACHMENT1,reveal),
            (GL_DEPTH_STENCIL_ATTACHMENT,depth_stencil)
        )
        transparentFBO = FrameBuffer(transparentAttachments)

        ubo = MappedBuffer{UBO_Data}()
        reserve!(ubo, 1, 0)
        glBindBufferBase(GL_UNIFORM_BUFFER, 10, ubo._id);

        pixel_buffer = Buffer{UVec2}()
        reserve!(pixel_buffer, shrd._width * shrd._height * 5, 0)
        empty_vao = VertexArray()
        
        glEnable(GL_DEPTH_TEST)
        glDepthFunc(GL_LEQUAL)
        
        glEnable(GL_CULL_FACE)
        glCullFace(GL_BACK)

        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
        
        glEnable(GL_PROGRAM_POINT_SIZE)

        # ? It's empty because of "reset!".
        observers::Vector{RendererDNA} = RendererDNA[]
        renderers = PrimitiveRenderers(pipeline_loader)
        
        p = perspective(Float32(70.0),Float32(shrd._width/shrd._height),Float32(0.01),Float32(100.0))
        v = lookat(Vec3F(0.0,-5.0,0.0),Vec3F(0.0,0.0,0.0),Vec3F(0.0,0.0,1.0))
        vp = p * v 
        camPos = Vec3F(0.0,0.0,0.0)

        self = new(profiler,passes,cpu_stopwatch,shrd,pipeline_loader,observers,renderers,
            transparent_color_combiner,transparent_id_combiner,highlighter,buffer_clear,grid,
            rgba,id,depth_stencil,depth_stencil_behind_opaque,accum,reveal,
            opaqueFBO,behindOpaqueFBO,transparentFBO,
            ubo,pixel_buffer,empty_vao,
            gizmoGL,orthoGizmoGL,
            Vec3F(0.73,0.73,0.73),
            vp,v,p,camPos)
        
        self._observers = create_dependent_observers(self)
        return self
    end
end

function resetObservers!(self::OpenGLData)
    reset!(self._renderers)
    reset_dependent_observers(self, self._observers)
end

function glError2String(msg::GLenum)::String
    if msg == GL_INVALID_ENUM
        return "GL_INVALID_ENUM"
    elseif msg == GL_INVALID_VALUE
        return "GL_INVALID_VALUE"
    elseif msg == GL_INVALID_OPERATION
        return "GL_INVALID_OPERATION"
    elseif msg == GL_OUT_OF_MEMORY
        return "GL_OUT_OF_MEMORY"
    elseif msg == GL_INVALID_FRAMEBUFFER_OPERATION
        return "GL_INVALID_FRAMEBUFFER_OPERATION"
    elseif msg == GL_NO_ERROR
        return "GL_NO_ERROR"
    else
        return "Error code = $(msg)"
    end
end

function glCheckErrors(::OpenGLData)
    glError = glGetError()
    if glError != GL_NO_ERROR
        while (glError != GL_NO_ERROR)
            println("$(glError2String(glError))")
            glError = glGetError()
        end
        error("OpenGL error(s) occured!")
    end
end

function resize!(self::OpenGLData)
    width = self._shrd._width
    height = self._shrd._height
    glViewport(0,0,width,height)
    resize!(self._rgbaTexture,width,height)
    resize!(self._idTexture,width,height)
    resize!(self._depthstencilTexture,width,height)
    resize!(self._behindOpaqueDepthstencilTexture,width,height)
    resize!(self._accumTexture,width,height)
    resize!(self._revealTexture,width,height)
    reserve!(self._pixel_buffer, self._shrd._width * self._shrd._height * 5, 0)
end

function readID(self::OpenGLData)
    x = self._shrd._mouseX
    y = self._shrd._mouseY
    width = self._shrd._width
    height = self._shrd._height

    if self._shrd._mouseMoved && x<width && y<height
        activate(self._opaqueFBO)
        glReadBuffer(GL_COLOR_ATTACHMENT1)
        num = Array{UInt32}(undef,1)
        glReadPixels(x, y, 1, 1, GL_RED_INTEGER, GL_UNSIGNED_INT,num)
        self._shrd._selectedID = num[1]
        disable(self._opaqueFBO)
    end
end

function _predraw(self::OpenGLData,cam::Camera)::Nothing
    bind_ssbo(self._pixel_buffer,11)
    activate(self._buffer_clear)
    glDispatchCompute(cld(length(self._pixel_buffer),128*5),1,1)
    unbind_ssbo(11)

    # Clear opaque
    activate(self._opaqueFBO)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT)
    clear_value = SVector{4, UInt32}(0, 0, 0, 0)
    glClearBufferuiv(GL_COLOR, 1, clear_value)
    # Clear transparent
    activate(self._transparentFBO)
    glClearBufferfv(GL_COLOR, 0, Float32[0.0f0, 0.0f0, 0.0f0, 0.0f0])
    glClearBufferfv(GL_COLOR, 1, Float32[1.0f0, 1.0f0, 1.0f0, 1.0f0])

    # Pre draw call
    glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT | GL_BUFFER_UPDATE_BARRIER_BIT)
    pre_draw(self._renderers,cam,self._shrd)
end

function _opaque(self::OpenGLData,cam::Camera)::Nothing
    glStencilFunc(GL_ALWAYS, 1, 0xFF)
    glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE)
    glEnable(GL_STENCIL_TEST)
    opaque(self._renderers,cam,self._shrd)

    glStencilFunc(GL_ALWAYS, 2, 0xFF)
    opaque_occluder(self._renderers,cam,self._shrd)
    glDisable(GL_STENCIL_TEST)
    return nothing
end

function _behind_opaque(self::OpenGLData,cam::Camera)::Nothing
    glBindFramebuffer(GL_READ_FRAMEBUFFER, self._opaqueFBO._id)
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, self._behindOpaqueFBO._id)
    glBlitFramebuffer(
        0, 0, self._shrd._width, self._shrd._height,
        0, 0, self._shrd._width, self._shrd._height,
        GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT, 
        GL_NEAREST
    )
    activate(self._behindOpaqueFBO)
    glClear(GL_DEPTH_BUFFER_BIT)
    glStencilFunc(GL_EQUAL, 2, 0xFF);
    glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP)

    glEnable(GL_STENCIL_TEST);
    behind_opaque(self._renderers,cam,self._shrd)
    glDisable(GL_STENCIL_TEST);
    return nothing
end

function _transparent(self::OpenGLData,cam::Camera)
    glDisable(GL_DEPTH_TEST)::Nothing
    glEnable(GL_BLEND)::Nothing
    glDisable(GL_CULL_FACE)::Nothing
    glBlendFunci(0, GL_ONE, GL_ONE)::Nothing
    glBlendFunci(1, GL_ZERO, GL_ONE_MINUS_SRC_COLOR)::Nothing
    glBlendEquation(GL_FUNC_ADD)::Nothing

    activate(self._transparentFBO)
    bind_ssbo(self._pixel_buffer,11)
    
    # draws
    activate(self._depthstencilTexture,GL_TEXTURE12)
    transparent(self._renderers,cam,self._shrd)
    
    glEnable(GL_DEPTH_TEST)
    glEnable(GL_CULL_FACE)
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    glDepthMask(GL_FALSE)
    
    activate(self._opaqueFBO)
    activate(self._empty_VAO)
    
    glColorMaski(1,GL_FALSE,GL_FALSE,GL_FALSE,GL_FALSE)
    # color
    activate(self._transparent_color_combiner)
    activate(self._accumTexture,GL_TEXTURE0)
    activate(self._revealTexture,GL_TEXTURE1)
    glDrawArrays(GL_TRIANGLES,UInt32(0),Int32(3))::Nothing
    glColorMaski(0,GL_FALSE,GL_FALSE,GL_FALSE,GL_FALSE)
    glColorMaski(1,GL_TRUE,GL_TRUE,GL_TRUE,GL_TRUE)
    # id
    glEnable(GL_STENCIL_TEST)
    glStencilFunc(GL_EQUAL, 0, 0xff)
    glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP)
    activate(self._transparent_id_combiner)
    glDrawArrays(GL_TRIANGLES,UInt32(0),Int32(3))::Nothing
    glDisable(GL_STENCIL_TEST)
    
    glColorMaski(0,GL_TRUE,GL_TRUE,GL_TRUE,GL_TRUE)
    
    glDisable(GL_BLEND)
    glDepthMask(GL_TRUE)
    unbind_ssbo(11)
end

function _widgets(self::OpenGLData,cam::Camera)
    activate(self._opaqueFBO)
    glDepthFunc(GL_ALWAYS)

    glDisable(GL_BLEND)
    glEnablei(GL_BLEND, 0)
    glDisablei(GL_BLEND, 1)
    glBlendFunci(0, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
    if self._shrd._gizmoEnabled draw(self._gizmoGL,self._shrd._gizmoConstraints) end
    draw(self._orthoGizmoGL)

    glDepthFunc(GL_LEQUAL)
    glDisable(GL_BLEND)
end

function render_scene!(self::OpenGLData,cam::Camera)
    begin_gpu(self._profiler,self._passes.pre_draw)
    _predraw(self,cam)
    end_gpu(self._profiler,self._passes.pre_draw)

    begin_gpu(self._profiler,self._passes.widgets)
    _widgets(self,cam)
    end_gpu(self._profiler,self._passes.widgets)

    begin_gpu(self._profiler,self._passes.opaque)
    _opaque(self,cam)
    end_gpu(self._profiler,self._passes.opaque)

    begin_gpu(self._profiler,self._passes.behind_opaque)
    _behind_opaque(self,cam)
    end_gpu(self._profiler,self._passes.behind_opaque)

    begin_gpu(self._profiler,self._passes.transparent)
    _transparent(self,cam)
    end_gpu(self._profiler,self._passes.transparent)
end

function blit_scene!(self::OpenGLData,cam::Camera)
    glDisable(GL_DEPTH_TEST)
    glBindFramebuffer(GL_FRAMEBUFFER, 0)
    glClear(GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT)
    glEnable(GL_BLEND)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

    w = GLint(self._shrd._width)
    h = GLint(self._shrd._height)
    blit_to_screen(self._opaqueFBO, GL_COLOR_ATTACHMENT0, GL_COLOR_BUFFER_BIT, w, h)

    activate(self._empty_VAO)

    activate(self._grid)
    activate(self._depthstencilTexture,GL_TEXTURE0)
    glDrawArrays(GL_TRIANGLES,0,3)

    if (self._shrd._selectedID > 3)
        activate(self._highlighter)
        activate(self._idTexture,GL_TEXTURE0)
        glDrawArrays(GL_TRIANGLES,0,3)
    end

    glEnable(GL_DEPTH_TEST)
end

function _ubo_update!(self::OpenGLData,cam::Camera)
    # Ubo update
    (vp, v, p) = get_matrices(cam)
    (cam_light, side_light) = get_lights(cam)
    glBindBufferBase(GL_UNIFORM_BUFFER, 10, 0)
    
    width::Float32 = Float32(self._shrd._width)
    height::Float32 = Float32(self._shrd._height)
    wait(self._ubo)
    self._ubo[1] = UBO_Data(
        vp,v,p,
        Vec4F(-side_light...,width),Vec4F(-cam_light...,height),
        Vec4F(cam._eye...,width/height),Vec4F(cam._at...,reinterpret(Float32,UInt32(self._shrd._width))),
        Vec4F(cam._zNear,cam._zFar,deg2rad(cam._fov),reinterpret(Float32,self._shrd._selectedID))
    )
    glBindBufferBase(GL_UNIFORM_BUFFER, 10, id(self._ubo))
end

function update!(self::OpenGLData,cam::Camera,scene_change::Bool)
    glCheckErrors(self)
    begin_cpu(self._profiler, self._cpu_stopwatch)
    readID(self)

    _ubo_update!(self,cam)
    added_all!(self._renderers)
    scene_change |= update!(self._pipeline_loader)
    scene_change |= sync_all!(self._renderers)
    if scene_change
        render_scene!(self,cam)
    end

    begin_gpu(self._profiler,self._passes.post_process)
    blit_scene!(self,cam)
    end_gpu(self._profiler,self._passes.post_process)

    lock(self._ubo)
    end_cpu(self._profiler, self._cpu_stopwatch)
    frame_end(self._profiler)
end

function destroy!(self::OpenGLData)
    destroy!(self._pipeline_loader)
    destroy_dependent_observers(self._observers)
    destroy!(self._renderers)

    destroy!(self._opaqueFBO)
    destroy!(self._behindOpaqueFBO)
    destroy!(self._transparentFBO)
    destroy!(self._pixel_buffer)

    destroy!(self._rgbaTexture)
    destroy!(self._idTexture)
    destroy!(self._accumTexture)
    destroy!(self._revealTexture)
    destroy!(self._depthstencilTexture)
    destroy!(self._behindOpaqueDepthstencilTexture)

    destroy!(self._gizmoGL)
end