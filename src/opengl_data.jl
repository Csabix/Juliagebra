
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

mutable struct OpenGLData <: ObserverBuilderDNA
    _shrd::SharedData
    _widgets::Vector{OpenGLWidgetDNA}

    _observers::Vector{RendererDNA}
    _renderers::PrimitiveRenderers

    # ! Shaders
    _transparent_color_combiner::ShaderProgram
    _transparent_id_combiner::ShaderProgram
    _final_combiner::ShaderProgram

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
    function OpenGLData(::GLFWData,shrd::SharedData)
        c_debug_callback = @cfunction(debug_callback, Nothing, 
                                 (GLenum, GLenum, GLuint, GLenum, GLsizei, Ptr{GLchar}, Ptr{Cvoid}))
        glEnable(GL_DEBUG_OUTPUT)
        glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS)
        glDebugMessageCallback(c_debug_callback, C_NULL)

        # ! for OpenGLData to succesfully construct, a GLFWData is required, but not stored
        glClearStencil(0)
        glStencilMask(0xFF);
        glClearColor(0.73f0,0.73f0,0.73f0,1.0f0)
        
        widgets = Vector{OpenGLWidgetDNA}()
        gizmoGL = GizmoGL()
        orthoGizmoGL = OrthoGizmoGL()

        push!(widgets,gizmoGL)
        push!(widgets,orthoGizmoGL)

        transparent_color_combiner = ShaderProgram(["combiners/fullscreen.vert","combiners/transparent_color.frag"],["width"])
        transparent_id_combiner = ShaderProgram(["combiners/fullscreen.vert","combiners/transparent_id.frag"],["width"])
        final_combiner = ShaderProgram(["combiners/fullscreen.vert","combiners/final.frag"],["frameTex","depthTex","AT","EYE","ASPECT_FOV_RESOLUTION","NEAR_FAR_DISTANCE_POWER"])

        depth_stencil = Texture2D(shrd._width,shrd._height,GL_DEPTH24_STENCIL8,GL_DEPTH_STENCIL,GL_UNSIGNED_INT_24_8)
        depth_stencil_behind_opaque = Texture2D(shrd._width,shrd._height,GL_DEPTH24_STENCIL8,GL_DEPTH_STENCIL,GL_UNSIGNED_INT_24_8)
        id = createIDTexture2D(shrd._width,shrd._height)
        rgba = Texture2D(shrd._width,shrd._height,GL_RGBA16F,GL_RGBA,GL_HALF_FLOAT)
        accum = Texture2D(shrd._width,shrd._height,GL_RGBA16F,GL_RGBA,GL_HALF_FLOAT)
        reveal = Texture2D(shrd._width,shrd._height,GL_R8,GL_RED,GL_FLOAT)

        opaqueAttachements = Dict{GLuint,Texture2D}()
        opaqueAttachements[GL_COLOR_ATTACHMENT0] = rgba
        opaqueAttachements[GL_COLOR_ATTACHMENT1] = id
        opaqueAttachements[GL_DEPTH_STENCIL_ATTACHMENT] = depth_stencil
        opaqueFBO = FrameBuffer(opaqueAttachements)

        behindOpaqueAttachements = Dict{GLuint,Texture2D}()
        behindOpaqueAttachements[GL_COLOR_ATTACHMENT0] = rgba
        behindOpaqueAttachements[GL_COLOR_ATTACHMENT1] = id
        behindOpaqueAttachements[GL_DEPTH_STENCIL_ATTACHMENT] = depth_stencil_behind_opaque
        behindOpaqueFBO = FrameBuffer(behindOpaqueAttachements)

        transparentAttachments = Dict{GLuint,Texture2D}()
        transparentAttachments[GL_COLOR_ATTACHMENT0] = accum
        transparentAttachments[GL_COLOR_ATTACHMENT1] = reveal
        transparentAttachments[GL_DEPTH_STENCIL_ATTACHMENT] = depth_stencil
        transparentFBO = FrameBuffer(transparentAttachments)

        pixel_buffer = Buffer{UVec2}()
        reserve!(pixel_buffer, shrd._width * shrd._height * 10, 0)
        empty_vao = VertexArray()
        
        glEnable(GL_DEPTH_TEST)
        glDepthFunc(GL_LEQUAL)
        
        glEnable(GL_CULL_FACE)
        glCullFace(GL_BACK)

        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
        
        glEnable(GL_PROGRAM_POINT_SIZE)

        # ? It's empty because of "reset!".
        observers::Vector{RendererDNA} = RendererDNA[]
        renderers = PrimitiveRenderers()
        
        p = perspective(Float32(70.0),Float32(shrd._width/shrd._height),Float32(0.01),Float32(100.0))
        v = lookat(Vec3F(0.0,-5.0,0.0),Vec3F(0.0,0.0,0.0),Vec3F(0.0,0.0,1.0))
        vp = p * v 
        camPos = Vec3F(0.0,0.0,0.0)

        self = new(shrd,widgets,observers,renderers,
            transparent_color_combiner,transparent_id_combiner,final_combiner,
            rgba,id,depth_stencil,depth_stencil_behind_opaque,accum,reveal,
            opaqueFBO,behindOpaqueFBO,transparentFBO,
            pixel_buffer,empty_vao,
            gizmoGL,orthoGizmoGL,
            Vec3F(0.73,0.73,0.73),
            vp,v,p,camPos)
        
        self._observers = create_dependent_observers(self)
        return self
    end
end

function reset!(self::OpenGLData)
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
    reserve!(self._pixel_buffer, self._shrd._width * self._shrd._height * 10, 0)
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

function readID(self::OpenGLData,x,y)::UInt32
    width = self._shrd._width
    height = self._shrd._height
    y = self._shrd._height - y
    if x >= width || y >= height
        return 0
    end

    # TODO handling window size != buffer size

    activate(self._opaqueFBO)
    glReadBuffer(GL_COLOR_ATTACHMENT1)
    num = Array{UInt32}(undef,1)
    glReadPixels(x, y, 1, 1, GL_RED_INTEGER, GL_UNSIGNED_INT,num)
    disable(self._opaqueFBO)
    return num[1]
end

function _opaque(self::OpenGLData,cam::Camera)::Nothing
    activate(self._opaqueFBO)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT)
    clear_value = SVector{4, UInt32}(0, 0, 0, 0)
    glClearBufferuiv(GL_COLOR, 1, clear_value)

    glStencilFunc(GL_ALWAYS, 1, 0xFF)
    glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE)
    # TODO
    glEnable(GL_STENCIL_TEST)
    opaque(self._renderers,cam,self._shrd)
    glDisable(GL_STENCIL_TEST)
    return nothing
end

function _opaque_lines(self::OpenGLData,cam::Camera)::Nothing
    activate(self._opaqueFBO)
    glStencilFunc(GL_ALWAYS, 1, 0xFF)
    glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE)
    glEnable(GL_STENCIL_TEST)
    opaque_lines(self._renderers,cam,self._shrd)
    glDisable(GL_STENCIL_TEST)
    return nothing
end

function _behind_opaque(self::OpenGLData,cam::Camera)::Nothing
    activate(self._opaqueFBO)
    glDepthFunc(GL_GREATER)
    glDepthMask(GL_FALSE)
    behind_opaque(self._renderers,cam,self._shrd)
    glDepthMask(GL_TRUE)
    glDepthFunc(GL_LEQUAL)
    return nothing
end

function _transparent(self::OpenGLData,cam::Camera)
    glDepthMask(GL_FALSE)::Nothing
    glEnable(GL_BLEND)::Nothing
    glDisable(GL_CULL_FACE)::Nothing
    glBlendFunci(0, GL_ONE, GL_ONE)::Nothing
    glBlendFunci(1, GL_ZERO, GL_ONE_MINUS_SRC_COLOR)::Nothing
    glBlendEquation(GL_FUNC_ADD)::Nothing

    activate(self._transparentFBO)
    glClearBufferfv(GL_COLOR, 0, Float32[0.0f0, 0.0f0, 0.0f0, 0.0f0])
    glClearBufferfv(GL_COLOR, 1, Float32[1.0f0, 1.0f0, 1.0f0, 1.0f0])
    
    bind_ssbo(self._pixel_buffer,0)
    
    # draws
    glMemoryBarrier(GL_BUFFER_UPDATE_BARRIER_BIT)
    activate(self._depthstencilTexture,GL_TEXTURE0)
    transparent(self._renderers,cam,self._shrd)
    
    glEnable(GL_CULL_FACE)
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    
    activate(self._opaqueFBO)
    activate(self._empty_VAO)
    
    glColorMaski(1,GL_FALSE,GL_FALSE,GL_FALSE,GL_FALSE)
    # color
    activate(self._transparent_color_combiner)
    activate(self._accumTexture,GL_TEXTURE0)
    activate(self._revealTexture,GL_TEXTURE1)
    uniform(self._transparent_color_combiner,"width",UInt32(self._shrd._width))
    glDrawArrays(GL_TRIANGLES,UInt32(0),Int32(3))::Nothing
    
    glColorMaski(0,GL_FALSE,GL_FALSE,GL_FALSE,GL_FALSE)
    glColorMaski(1,GL_TRUE,GL_TRUE,GL_TRUE,GL_TRUE)
    # id
    glEnable(GL_STENCIL_TEST)
    glStencilFunc(GL_EQUAL, 0, 0xff)
    glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP)
    activate(self._transparent_id_combiner)
    uniform(self._transparent_color_combiner,"width",UInt32(self._shrd._width))
    glDrawArrays(GL_TRIANGLES,UInt32(0),Int32(3))::Nothing
    glDisable(GL_STENCIL_TEST)
    
    glColorMaski(0,GL_TRUE,GL_TRUE,GL_TRUE,GL_TRUE)
    
    
    glClearNamedBufferData(id(self._pixel_buffer),GL_R32UI,GL_RED_INTEGER,GL_UNSIGNED_INT,Ref(UInt32(0)))
    glDisable(GL_BLEND)
    glDepthMask(GL_TRUE)
end

function _widgets(self::OpenGLData,cam::Camera)
    activate(self._opaqueFBO)
    glDepthFunc(GL_ALWAYS)

    wh = Vec2F(self._shrd._width,self._shrd._height)

    # Color pass: blend on for anti-aliasing, but mask the integer ID attachment
    # (GL_BLEND + integer attachment = GL_INVALID_OPERATION, so mask it off here)
    glColorMaski(1,GL_FALSE,GL_FALSE,GL_FALSE,GL_FALSE)
    glEnable(GL_BLEND)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
    if self._shrd._gizmoEnabled draw(self._gizmoGL,self._vp,cam,self._shrd._selectedGizmo,wh) end
    draw(self._orthoGizmoGL,cam,wh)
    glDisable(GL_BLEND)
    glColorMaski(1,GL_TRUE,GL_TRUE,GL_TRUE,GL_TRUE)

    # ID pass: blend off, mask color, write only IDs for hit-testing
    if self._shrd._gizmoEnabled
        glColorMaski(0,GL_FALSE,GL_FALSE,GL_FALSE,GL_FALSE)
        draw(self._gizmoGL,self._vp,cam,self._shrd._selectedGizmo,wh)
        glColorMaski(0,GL_TRUE,GL_TRUE,GL_TRUE,GL_TRUE)
    end

    glDepthFunc(GL_LEQUAL)
end

function update!(self::OpenGLData,cam::Camera)
    glCheckErrors(self)

    added_all!(self._renderers)
    sync_all!(self._renderers)

    pre_draw(self._renderers,cam,self._shrd)
    _opaque(self,cam)
    _behind_opaque(self,cam)
    _opaque_lines(self,cam)
    _transparent(self,cam)
    _widgets(self,cam)

    readID(self)
    glBindFramebuffer(GL_FRAMEBUFFER, 0)
    activate(self._empty_VAO)
    distance = 10 ^ floor(log10(norm(cam._at - cam._eye)))
    activate(self._final_combiner)
    uniform(self._final_combiner,"frameTex",Int32(0))
    uniform(self._final_combiner,"depthTex",Int32(1))
    uniform(self._final_combiner,"EYE",cam._eye)
    uniform(self._final_combiner,"AT",cam._at)
    uniform(self._final_combiner,"NEAR_FAR_DISTANCE_POWER",Vec3F(cam._zNear,cam._zFar,distance))
    uniform(self._final_combiner,"ASPECT_FOV_RESOLUTION",Vec4F(Float32(self._shrd._width)/Float32(self._shrd._height),deg2rad(cam._fov),Float32(self._shrd._width),Float32(self._shrd._height)))
    activate(self._rgbaTexture,GL_TEXTURE0)
    activate(self._depthstencilTexture,GL_TEXTURE1)
    glDrawArrays(GL_TRIANGLES,0,6)
end



function destroy!(self::OpenGLData)
    destroy_dependent_observers(self._observers)
    destroy!(self._renderers)

    destroy!(self._transparent_color_combiner)
    destroy!(self._transparent_id_combiner)
    destroy!(self._final_combiner)

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