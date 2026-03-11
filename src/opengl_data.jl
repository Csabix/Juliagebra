
# ? ---------------------------------
# ! OpenGLData
# ? ---------------------------------

mutable struct OpenGLData <: ObserverBuilderDNA
    _shrd::SharedData
    _widgets::Vector{OpenGLWidgetDNA}

    _renderers::Vector{RendererDNA}

    # ! Shaders
    _transparent_combinerShader::ShaderProgram
    _combinerShader::ShaderProgram
    _centerShader::ShaderProgram

    # ! Main FBO objects
    _rgbaTexture::Texture2D
    _idTexture::Texture2D
    _depthstencilTexture::Texture2D
    _behindOpaqueDepthstencilTexture::Texture2D
    _accumTexture::Texture2D
    _revealTexture::Texture2D

    _opaqueFBO::FrameBuffer
    _idFBO::FrameBuffer
    _behindOpaqueFBO::FrameBuffer
    _transparentFBO::FrameBuffer
    _widgetFBO::FrameBuffer
    
    _dummyBufferArray::BufferArray
    _centerBufferArray::BufferArray
    _gizmoGL::GizmoGL
    _orthoGizmoGL::OrthoGizmoGL

    _backgroundCol::Vec3F

    _vp::Mat4T
    _v::Mat4T
    _p::Mat4T
    _camPos::Vec3F

    # GREEN Thread, runs this inside Init, after this construction can begin
    function OpenGLData(::GLFWData,shrd::SharedData)
        # ! for OpenGLData to succesfully construct, a GLFWData is required, but not stored
        glClearStencil(0)
        glStencilMask(0xFF);
        glClearColor(0.73f0,0.73f0,0.73f0,1.0f0)
        
        widgets = Vector{OpenGLWidgetDNA}()
        gizmoGL = GizmoGL()
        orthoGizmoGL = OrthoGizmoGL()

        push!(widgets,gizmoGL)
        push!(widgets,orthoGizmoGL)

        transparent_combinerShader = ShaderProgram(sp("combiner_transparent.vert"),sp("combiner_transparent.frag"))
        combinerShader  = ShaderProgram(sp("dflt_combiner.vert"),sp("dflt_combiner.frag"),["frameTex","depthTex","AT","EYE","ASPECT_FOV","NEAR_FAR_DISTANCE_POWER"])
        centerShader    = ShaderProgram(sp("center.vert")       ,sp("center.frag"))

        depth_stencil = Texture2D(shrd._width,shrd._height,GL_DEPTH24_STENCIL8,GL_DEPTH_STENCIL,GL_UNSIGNED_INT_24_8)
        depth_stencil_behind_opaque = Texture2D(shrd._width,shrd._height,GL_DEPTH24_STENCIL8,GL_DEPTH_STENCIL,GL_UNSIGNED_INT_24_8)
        id = createIDTexture2D(shrd._width,shrd._height)
        rgba = Texture2D(shrd._width,shrd._height,GL_RGBA16F,GL_RGBA,GL_HALF_FLOAT)
        accum = Texture2D(shrd._width,shrd._height,GL_RGBA16F,GL_RGBA,GL_HALF_FLOAT)
        reveal = Texture2D(shrd._width,shrd._height,GL_R8,GL_RED,GL_FLOAT)

        opaqueAttachements = Dict{GLuint,Texture2D}()
        opaqueAttachements[GL_COLOR_ATTACHMENT0] = rgba
        opaqueAttachements[GL_DEPTH_STENCIL_ATTACHMENT] = depth_stencil
        opaqueFBO = FrameBuffer(opaqueAttachements)

        idAttachements = Dict{GLuint,Texture2D}()
        idAttachements[GL_COLOR_ATTACHMENT0] = id
        idAttachements[GL_DEPTH_STENCIL_ATTACHMENT] = depth_stencil
        idFBO = FrameBuffer(idAttachements)

        behindOpaqueAttachements = Dict{GLuint,Texture2D}()
        behindOpaqueAttachements[GL_COLOR_ATTACHMENT0] = rgba
        behindOpaqueAttachements[GL_DEPTH_STENCIL_ATTACHMENT] = depth_stencil_behind_opaque
        behindOpaqueFBO = FrameBuffer(behindOpaqueAttachements)

        transparentAttachments = Dict{GLuint,Texture2D}()
        transparentAttachments[GL_COLOR_ATTACHMENT0] = accum
        transparentAttachments[GL_COLOR_ATTACHMENT1] = reveal
        transparentAttachments[GL_DEPTH_STENCIL_ATTACHMENT] = depth_stencil
        transparentFBO = FrameBuffer(transparentAttachments)

        widgetAttachments = Dict{GLuint,Texture2D}()
        widgetAttachments[GL_COLOR_ATTACHMENT0] = rgba
        widgetAttachments[GL_COLOR_ATTACHMENT1] = id
        widgetAttachments[GL_DEPTH_STENCIL_ATTACHMENT] = depth_stencil
        widgetFBO = FrameBuffer(widgetAttachments)


        dummyBufferArray = BufferArray(Vec3F,GL_STATIC_DRAW,getAPlane())
        centerBufferArray = BufferArray(Vec3F,GL_STATIC_DRAW,Vector{Vec3F}([Vec3F(0.0,0.0,-1.0)]))
        
        glEnable(GL_DEPTH_TEST)
        glDepthFunc(GL_LEQUAL)
        
        glEnable(GL_CULL_FACE)
        glCullFace(GL_BACK)

        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);  
        
        glEnable(GL_PROGRAM_POINT_SIZE)

        # ? It's empty because of "reset!".
        renderers::Vector{RendererDNA} = []
        
        p = perspective(Float32(70.0),Float32(shrd._width/shrd._height),Float32(0.01),Float32(100.0))
        v = lookat(Vec3F(0.0,-5.0,0.0),Vec3F(0.0,0.0,0.0),Vec3F(0.0,0.0,1.0))
        vp = p * v 
        camPos = Vec3F(0.0,0.0,0.0)

        self = new(shrd,widgets,renderers,
            transparent_combinerShader,combinerShader,centerShader,
            rgba,id,depth_stencil,depth_stencil_behind_opaque,accum,reveal,
            opaqueFBO,idFBO,behindOpaqueFBO,transparentFBO,widgetFBO,
            dummyBufferArray,centerBufferArray,gizmoGL,orthoGizmoGL,
            Vec3F(0.73,0.73,0.73),
            vp,v,p,camPos)
        
        reset!(self)
        return self
    end
end

function reset!(self::OpenGLData)
    # ? Clean up all Renderers.
    for renderer in self._renderers
        destroy!(renderer)
    end
    
    # ? Reset Renderer Vectors.
    self._renderers::Vector{RendererDNA} = [
        SphereRenderer(self),
        ParametricSurfaceRenderer(self),
        CurveRenderer(self),
        PointRenderer(self)
    ]
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
end

function readID(self::OpenGLData)
    x = self._shrd._mouseX
    y = self._shrd._mouseY
    width = self._shrd._width
    height = self._shrd._height

    if self._shrd._mouseMoved && x<width && y<height
        activate(self._idFBO)
        glReadBuffer(GL_COLOR_ATTACHMENT0)
        num = Array{UInt32}(undef,1)
        glReadPixels(x, y, 1, 1, GL_RED_INTEGER, GL_UNSIGNED_INT,num)
        self._shrd._selectedID = num[1]
        disable(self._idFBO)
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

    activate(self._idFBO)
    glReadBuffer(GL_COLOR_ATTACHMENT0)
    num = Array{UInt32}(undef,1)
    glReadPixels(x, y, 1, 1, GL_RED_INTEGER, GL_UNSIGNED_INT,num)
    disable(self._idFBO)
    return num[1]
end

function _pre_draw!(self::OpenGLData,cam::Camera)
    for renderer in self._renderers
        if hasInstance(renderer) pre_draw!(renderer,self._vp,cam,self._shrd) end
    end
end

function _id_pass!(self::OpenGLData,cam::Camera)
    clear_value = Int32[0, 0, 0, 0]
    activate(self._idFBO)
    glClear(GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT)
    glClearBufferiv(GL_COLOR, 0, clear_value)
    for renderer in self._renderers
        if hasInstance(renderer) id_pass!(renderer,self._vp,cam,self._shrd) end
    end
    glInvalidateFramebuffer(GL_FRAMEBUFFER,1,[GL_DEPTH_STENCIL_ATTACHMENT])
end

function _opaque_pass!(self::OpenGLData,cam::Camera)
    glStencilFunc(GL_ALWAYS, 1, 0xFF);
    glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE)

    activate(self._opaqueFBO)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT)

    for renderer in self._renderers
        if hasInstance(renderer) && is_occluder(renderer)
            opaque_pass!(renderer,self._vp,cam,self._shrd)
        end
    end

    glEnable(GL_STENCIL_TEST)
    for renderer in self._renderers
        if hasInstance(renderer) && !is_occluder(renderer)
            opaque_pass!(renderer,self._vp,cam,self._shrd)
        end
    end
    glDisable(GL_STENCIL_TEST)
end

function _behind_opaque_pass!(self::OpenGLData,cam::Camera)
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
    glStencilFunc(GL_GREATER, 1, 0xFF);
    glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP)

    glEnable(GL_STENCIL_TEST);
    for renderer in self._renderers
        if hasInstance(renderer) behind_opaque_pass!(renderer,self._vp,cam,self._shrd) end
    end
    glDisable(GL_STENCIL_TEST);
end

function _transparent_pass!(self::OpenGLData,cam::Camera)
    clear_value_zero = Float32[0.0f0,0.0f0,0.0f0,0.0f0]
    clear_value_one = Float32[1.0f0,1.0f0,1.0f0,1.0f0]
    glDepthMask(GL_FALSE)
    glEnable(GL_BLEND)
    glBlendFunci(0, GL_ONE, GL_ONE)
    glBlendFunci(1, GL_ZERO, GL_ONE_MINUS_SRC_COLOR)
    glBlendEquation(GL_FUNC_ADD)

    activate(self._transparentFBO)
    glClearBufferfv(GL_COLOR, 0, clear_value_zero)
    glClearBufferfv(GL_COLOR, 1, clear_value_one)

    for renderer in self._renderers
        if hasInstance(renderer) transparent_pass!(renderer,self._vp,cam,self._shrd) end
    end

    glDepthFunc(GL_ALWAYS);
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	activate(self._opaqueFBO);
	activate(self._transparent_combinerShader);
    activate(self._accumTexture,GL_TEXTURE0)
    activate(self._revealTexture,GL_TEXTURE1)
	draw(self._dummyBufferArray,GL_TRIANGLES)
	glDisable(GL_BLEND);
    glDepthFunc(GL_LEQUAL);
    glDepthMask(GL_TRUE)
end

function _widget_pass!(self::OpenGLData,cam::Camera)
    activate(self._widgetFBO)
    glDepthFunc(GL_ALWAYS)
    glEnable(GL_BLEND);

    wh = Vec2F(self._shrd._width,self._shrd._height)
    
    if self._shrd._gizmoEnabled draw(self._gizmoGL,self._vp,cam,self._shrd._selectedGizmo,wh) end
    draw(self._orthoGizmoGL,cam,wh)

    glDisable(GL_BLEND);
    glDepthFunc(GL_LEQUAL)
end

function update!(self::OpenGLData,cam::Camera)
    glCheckErrors(self)

    _pre_draw!(self,cam)
    _id_pass!(self,cam)
    _opaque_pass!(self,cam)
    _behind_opaque_pass!(self,cam)
    _transparent_pass!(self,cam)
    _widget_pass!(self,cam)

    #activate(self._centerShader)
    #draw(self._centerBufferArray,GL_POINTS)

    readID(self)
    glBindFramebuffer(GL_FRAMEBUFFER, 0)

    distance = 10 ^ floor(log10(norm(cam._at - cam._eye)))
    activate(self._combinerShader)
    setUniform!(self._combinerShader,"frameTex",Int32(0))
    setUniform!(self._combinerShader,"depthTex",Int32(1))
    setUniform!(self._combinerShader,"EYE",cam._eye)
    setUniform!(self._combinerShader,"AT",cam._at)
    setUniform!(self._combinerShader,"NEAR_FAR_DISTANCE_POWER",Vec3F(cam._zNear,cam._zFar,distance))
    setUniform!(self._combinerShader,"ASPECT_FOV",Vec2F(Float32(self._shrd._width)/Float32(self._shrd._height),deg2rad(cam._fov)))
    activate(self._rgbaTexture,GL_TEXTURE0)
    activate(self._depthstencilTexture,GL_TEXTURE1)
    draw(self._dummyBufferArray,GL_TRIANGLES)
end



function destroy!(self::OpenGLData)
    for renderer in self._renderers
        destroy!(renderer)
    end

    destroy!(self._transparent_combinerShader)
    destroy!(self._combinerShader)
    destroy!(self._centerShader)

    destroy!(self._idFBO)
    destroy!(self._opaqueFBO)
    destroy!(self._behindOpaqueFBO)
    destroy!(self._transparentFBO)
    destroy!(self._widgetFBO)

    destroy!(self._rgbaTexture)
    destroy!(self._idTexture)
    destroy!(self._accumTexture)
    destroy!(self._revealTexture)
    destroy!(self._depthstencilTexture)
    destroy!(self._behindOpaqueDepthstencilTexture)

    destroy!(self._dummyBufferArray)
    destroy!(self._centerBufferArray)
    destroy!(self._gizmoGL)
end