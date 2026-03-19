
# ? ---------------------------------
# ! OpenGLData
# ? ---------------------------------
const _POINTS::UInt = 1
const _POINT_CLOUDS_STATIC::UInt = 2
const _POINT_CLOUDS_DYNAMIC::UInt = 3

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

        transparent_combinerShader = ShaderProgram(["combiner_transparent.vert","combiner_transparent.frag"])
        combinerShader  = ShaderProgram(["dflt_combiner.vert","dflt_combiner.frag"],["frameTex","depthTex","AT","EYE","ASPECT_FOV","NEAR_FAR_DISTANCE_POWER"])
        centerShader    = ShaderProgram(["center.vert","center.frag"])

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

        dummyBufferArray = BufferArray{Tuple{Vec3F}}()
        upload!(dummyBufferArray[1],getAPlane(),0)
        centerBufferArray = BufferArray{Tuple{Vec3F}}()
        upload!(centerBufferArray[1],Vector{Vec3F}([Vec3F(0.0,0.0,-1.0)]),0)
        
        glEnable(GL_DEPTH_TEST)
        glDepthFunc(GL_LEQUAL)
        
        glEnable(GL_CULL_FACE)
        glCullFace(GL_BACK)

        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);  
        
        glEnable(GL_PROGRAM_POINT_SIZE)

        # ? It's empty because of "reset!".
        renderers::Vector{RendererDNA} = RendererDNA[]
        
        p = perspective(Float32(70.0),Float32(shrd._width/shrd._height),Float32(0.01),Float32(100.0))
        v = lookat(Vec3F(0.0,-5.0,0.0),Vec3F(0.0,0.0,0.0),Vec3F(0.0,0.0,1.0))
        vp = p * v 
        camPos = Vec3F(0.0,0.0,0.0)

        self = new(shrd,widgets,renderers,
            transparent_combinerShader,combinerShader,centerShader,
            rgba,id,depth_stencil,depth_stencil_behind_opaque,accum,reveal,
            opaqueFBO,
            behindOpaqueFBO,transparentFBO,widgetFBO,
            dummyBufferArray,centerBufferArray,gizmoGL,orthoGizmoGL,
            Vec3F(0.73,0.73,0.73),
            vp,v,p,camPos)
        
        reset!(self)
        init_renderers!()
        return self
    end
end

function reset!(self::OpenGLData)
    # ? Clean up all Renderers.
    destroy!.(self._renderers)
    
    # ? Reset Renderer Vectors.
    self._renderers::Vector{RendererDNA} = [
        Points(self),
        StaticPointClouds(self),
        DynamicPointClouds(self)
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

function _pre_draw!(self::OpenGLData,cam::Camera)
    pre_draw!(cam,self.shrd)
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

    opaque!(self._opaqueFBO,cam,self._shrd)
    _widget_pass!(self,cam)

    #activate(self._centerShader)
    #draw(self._centerBufferArray,GL_POINTS)

    readID(self)
    glBindFramebuffer(GL_FRAMEBUFFER, 0)

    distance = 10 ^ floor(log10(norm(cam._at - cam._eye)))
    activate(self._combinerShader)
    uniform(self._combinerShader,"frameTex",Int32(0))
    uniform(self._combinerShader,"depthTex",Int32(1))
    uniform(self._combinerShader,"EYE",cam._eye)
    uniform(self._combinerShader,"AT",cam._at)
    uniform(self._combinerShader,"NEAR_FAR_DISTANCE_POWER",Vec3F(cam._zNear,cam._zFar,distance))
    uniform(self._combinerShader,"ASPECT_FOV",Vec2F(Float32(self._shrd._width)/Float32(self._shrd._height),deg2rad(cam._fov)))
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