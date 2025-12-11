
# * iter on employees to check changes
# * iter on opengldata for rendering

global DEBUG_FRAME = 0

mutable struct OpenGLData <: ObserverBuilderDNA
    _shrd::SharedData
    _widgets::Vector{OpenGLWidgetDNA}

    # TODO: Change Dictionary to an array. This suggestion might be a microoptimization.
    _renderOffices::Dict{<:DataType,Vector{<:RendererDNA}}
    _updateMeQueue::Queue{RendererDNA}
    
    # ! Shaders
    _combinerShader::ShaderProgram
    _bodyShader::ShaderProgram
    _centerShader::ShaderProgram

    # ! Main FBO objects
    _mainRGBATexture :: Texture2D
    _mainIDTexture :: Texture2D
    _mainDepthTexture :: Texture2D
    _mainFBO :: FrameBuffer
    
    _dummyBufferArray::BufferArray
    _centerBufferArray::BufferArray
    _gizmoGL::GizmoGL
    _orthoGizmoGL::OrthoGizmoGL


    _index :: Int

    _backgroundCol::Vec3F

    _vp::Mat4T
    _v::Mat4T
    _p::Mat4T
    _camPos::Vec3F

    function OpenGLData(glfw::GLFWData,shrd::SharedData)
        # ! for OpenGLData to succesfully construct, a GLFWData is required, but not stored
        glClearColor(0.73f0,0.73f0,0.73f0,1.0f0)
        
        widgets = Vector{OpenGLWidgetDNA}()
        gizmoGL = GizmoGL()
        orthoGizmoGL = OrthoGizmoGL()

        push!(widgets,gizmoGL)
        push!(widgets,orthoGizmoGL)

        combinerShader  = ShaderProgram(sp("dflt_combiner.vert"),sp("dflt_combiner.frag"),["frameTex","depthTex","AT","EYE","ASPECT_FOV","NEAR_FAR_DISTANCE_POWER"])
        bodyShader      = ShaderProgram(sp("body_3D.vert")      ,sp("body_3D.frag"),["VP"])
        centerShader    = ShaderProgram(sp("center.vert")       ,sp("center.frag"))

        mainAttachements = Dict{GLuint,Texture2D}()
        mainAttachements[GL_COLOR_ATTACHMENT0] = createRGBATexture2D(shrd._width,shrd._height)
        mainAttachements[GL_COLOR_ATTACHMENT1] = createIDTexture2D(shrd._width,shrd._height)
        mainAttachements[GL_DEPTH_ATTACHMENT] = createDepthTexture2D(shrd._width,shrd._height)
        mainFBO = FrameBuffer(mainAttachements)
        
        dummyBufferArray = BufferArray(Vec3F,GL_STATIC_DRAW,getAPlane())
        centerBufferArray = BufferArray(Vec3F,GL_STATIC_DRAW,Vector{Vec3F}([Vec3F(0.0,0.0,-1.0)]))

        glEnable(GL_DEPTH_TEST)
        glDepthFunc(GL_LEQUAL)
        
        glEnable(GL_CULL_FACE)
        glCullFace(GL_BACK)

        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);  
        
        #glPolygonMode(GL_BACK,GL_LINE)

        glEnable(GL_PROGRAM_POINT_SIZE)

        renderOffices = Dict{DataType,Vector{<:RendererDNA}}()
        updateMeQueue = Queue{RendererDNA}()
        
        p = perspective(Float32(70.0),Float32(shrd._width/shrd._height),Float32(0.01),Float32(100.0))
        v = lookat(Vec3F(0.0,-5.0,0.0),Vec3F(0.0,0.0,0.0),Vec3F(0.0,0.0,1.0))
        vp = p * v 
        camPos = Vec3F(0.0,0.0,0.0)

        new(shrd,widgets,renderOffices,updateMeQueue,
            combinerShader,bodyShader,centerShader,
            mainAttachements[GL_COLOR_ATTACHMENT0],mainAttachements[GL_COLOR_ATTACHMENT1],
            mainAttachements[GL_DEPTH_ATTACHMENT],
            mainFBO,
            dummyBufferArray,centerBufferArray,gizmoGL,orthoGizmoGL,
            0,
            Vec3F(0.73,0.73,0.73),
            vp,v,p,camPos)
    end
end

function SingleRendererTactic(self::OpenGLData,t::Type{T})::T where T<:RendererDNA
    myVector = get!(self._renderOffices,T,Vector{T}())

    if(length(myVector)!=1)
        push!(myVector,T(self))
    end

    return myVector[1]
end

function checkErrors(self::OpenGLData)
    # TODO: Make checkErrors prettier
    opengl_error = glGetError()
    if opengl_error != GL_NO_ERROR
        while (opengl_error != GL_NO_ERROR)
            println(string(opengl_error))
            opengl_error = glGetError()
        end
    error("OpenGL error(s) occured!")
    end
end

function resize!(self::OpenGLData)
    width = self._shrd._width
    height = self._shrd._height
    glViewport(0,0,width,height)
    resize!(self._mainRGBATexture,width,height)
    resize!(self._mainIDTexture,width,height)
    resize!(self._mainDepthTexture,width,height)
end

function readID(self::OpenGLData)
    x = self._shrd._mouseX
    y = self._shrd._mouseY
    width = self._shrd._width
    height = self._shrd._height

    if self._shrd._mouseMoved && x<width && y<height
        glReadBuffer(GL_COLOR_ATTACHMENT1)
        num = Array{UInt32}(undef,1)
        glReadPixels(x, y, 1, 1, GL_RED_INTEGER, GL_UNSIGNED_INT,num)
        self._shrd._selectedID = num[1]
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

    activate(self._mainFBO)
    glReadBuffer(GL_COLOR_ATTACHMENT1)
    num = Array{UInt32}(undef,1)
    glReadPixels(x, y, 1, 1, GL_RED_INTEGER, GL_UNSIGNED_INT,num)
    disable(self._mainFBO)
    return num[1]
end

function update!(self::OpenGLData,cam::Camera)
    checkErrors(self)
    
    self._index += 1
    global DEBUG_FRAME
    DEBUG_FRAME = self._index
    
    activate(self._mainFBO)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    glClearTexImage(self._mainIDTexture._id,0,GL_RED_INTEGER,GL_UNSIGNED_INT,Ref(0x0))

    activate(self._bodyShader)
    setUniform!(self._bodyShader,"VP",self._vp)  
    
    for (_,office) in self._renderOffices
        for renderer in office
            draw!(renderer,self._vp,self._shrd._selectedID,self._shrd._pickedID,cam,self._shrd)
        end
    end

    # TODO: refactor theese opengl widgets draw commands to something like this:
    # TODO: for widget in self._widgets
    # TODO:     render(widget)
    # TODO: end

    glDepthFunc(GL_ALWAYS)
    glEnable(GL_BLEND);
    # Gizmo here
    wh = Vec2F(self._shrd._width,self._shrd._height)
    
    if(self._shrd._gizmoEnabled)
        draw(self._gizmoGL,self._vp,cam,self._shrd._selectedGizmo,wh)
    end
    
    draw(self._orthoGizmoGL,cam,wh)

    glDisable(GL_BLEND);
    glDepthFunc(GL_LEQUAL)

    readID(self)
    #activate(self._centerShader)
    #draw(self._centerBufferArray,GL_POINTS)
    disable(self._mainFBO)

    distance = 10 ^ floor(log10(norm(cam._at - cam._eye)))
    activate(self._combinerShader)
    setUniform!(self._combinerShader,"frameTex",Int32(0))
    setUniform!(self._combinerShader,"depthTex",Int32(1))
    setUniform!(self._combinerShader,"EYE",cam._eye)
    setUniform!(self._combinerShader,"AT",cam._at)
    setUniform!(self._combinerShader,"NEAR_FAR_DISTANCE_POWER",Vec3F(cam._zNear,cam._zFar,distance))
    setUniform!(self._combinerShader,"ASPECT_FOV",Vec2F(Float32(self._shrd._width)/Float32(self._shrd._height),deg2rad(cam._fov)))
    activate(self._mainRGBATexture,GL_TEXTURE0)
    activate(self._mainDepthTexture,GL_TEXTURE1)
    draw(self._dummyBufferArray,GL_TRIANGLES)
end


function destroy!(self::OpenGLData)
    for (_, office) in self._renderOffices
        for renderer in office
            destroy!(renderer) 
        end
    end
    
    
    destroy!(self._combinerShader)
    destroy!(self._bodyShader)
    destroy!(self._centerShader)
    destroy!(self._mainFBO)
    destroy!(self._mainDepthTexture)
    destroy!(self._mainIDTexture)
    destroy!(self._mainRGBATexture)
    destroy!(self._dummyBufferArray)
    destroy!(self._centerBufferArray)
    destroy!(self._gizmoGL)
end

function print_render_offices(self::OpenGLData)
    printstyled("---------------\n";color=:white, bold=true)
    printstyled("Render Offices:\n";color=:yellow, bold=true)
    printstyled("---------------\n";color=:white, bold=true)

    for (key,office) in self._renderOffices
        printstyled("- ";color=:red,bold=true)
        printstyled("$key:\n";color=:green)
        for employee in office
            printstyled("\t- ";color=:red,bold=true)
            printstyled("$(string(employee)) - $(string(employee._asset))\n";color=:cyan)
        end
    end

end