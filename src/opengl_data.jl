
# * iter on employees to check changes
# * iter on opengldata for rendering

mutable struct OpenGLData
    _shrd::SharedData
    _widgets::Vector{OpenGLWidgetDNA}

    # TODO: Change Dictionary to an array. This suggestion might be a microoptimization.
    _renderOffices::Dict{<:DataType,Vector{<:RendererDNA}}
    _updateMeQueue::Queue{RendererDNA}
    
    # ! Shaders
    _combinerShader::ShaderProgram
    _backgroundShader::ShaderProgram
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
        glClearColor(1.0,0.0,1.0,1.0)
        
        widgets = Vector{OpenGLWidgetDNA}()
        gizmoGL = GizmoGL()
        orthoGizmoGL = OrthoGizmoGL()

        push!(widgets,gizmoGL)
        push!(widgets,orthoGizmoGL)

        backgroundShader= ShaderProgram(sp("dflt_bckg.vert")    ,sp("dflt_bckg.frag"),["bCol"])
        combinerShader  = ShaderProgram(sp("dflt_combiner.vert"),sp("dflt_combiner.frag"))
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
        
        #glPolygonMode(GL_BACK,GL_LINE)

        glEnable(GL_PROGRAM_POINT_SIZE)
        #glDisable(GL_POINT_SMOOTH)
        glEnable(GL_POINT_SPRITE)

        renderOffices = Dict{DataType,Vector{<:RendererDNA}}()
        updateMeQueue = Queue{RendererDNA}()
        
        p = perspective(Float32(70.0),Float32(shrd._width/shrd._height),Float32(0.01),Float32(100.0))
        v = lookat(Vec3F(0.0,-5.0,0.0),Vec3F(0.0,0.0,0.0),Vec3F(0.0,0.0,1.0))
        vp = p * v 
        camPos = Vec3F(0.0,0.0,0.0)

        new(shrd,widgets,renderOffices,updateMeQueue,
            combinerShader,backgroundShader,bodyShader,centerShader,
            mainAttachements[GL_COLOR_ATTACHMENT0],mainAttachements[GL_COLOR_ATTACHMENT1],
            mainAttachements[GL_DEPTH_ATTACHMENT],
            mainFBO,
            dummyBufferArray,centerBufferArray,gizmoGL,orthoGizmoGL,
            0,
            Vec3F(0.73,0.73,0.73),
            vp,v,p,camPos)
    end
end

function checkErrors(self::OpenGLData)
    # TODO: Make checkErrors prettier
    opengl_error = glGetError()
    if opengl_error != GL_NO_ERROR
        while (opengl_error != GL_NO_ERROR)
            @log string(opengl_error) ERR
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

function update!(self::OpenGLData,cam::Camera)
    checkErrors(self)
    self._index += 1
    
    while !isempty(self._updateMeQueue)
        renderer = sdequeue!(self._updateMeQueue)
        @log "($(string(self._index))) Updating renderer -> $(string(renderer))" INFO
        update!(renderer)
    end
    #glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
    #glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    # * All the buffers are up to date at this point.
    #glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    activate(self._mainFBO)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    
    activate(self._backgroundShader)
    setUniform!(self._backgroundShader,"bCol",self._backgroundCol)  
    draw(self._dummyBufferArray,GL_TRIANGLES)

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

    if(self._shrd._gizmoEnabled)
        draw(self._gizmoGL,self._vp,cam,self._shrd._selectedGizmo)
    end
    
    draw(self._orthoGizmoGL,cam,self._shrd._width,self._shrd._height)

    readID(self)
    #activate(self._centerShader)
    #draw(self._centerBufferArray,GL_POINTS)
    disable(self._mainFBO)

    activate(self._combinerShader)
    activate(self._mainRGBATexture,GL_TEXTURE0)
    draw(self._dummyBufferArray,GL_TRIANGLES)
end


function destroy!(self::OpenGLData)
    for (_, office) in self._renderOffices
        for renderer in office
            destroy!(renderer) 
        end
    end
    
    
    destroy!(self._combinerShader)
    destroy!(self._backgroundShader)
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