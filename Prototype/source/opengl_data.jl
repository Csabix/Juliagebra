
# * iter on employees to check changes
# * iter on opengldata for rendering

mutable struct OpenGLData
    _shrd::SharedData

    # TODO: Change Dictionary to an array. This suggestion might be a microoptimization.
    _renderOffices::Dict{<:DataType,Vector{<:RenderEmployee}}
    _updateMeQueue::Queue{RenderEmployee}
    
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

    _index :: Int

    _backgroundCol::Vec3

    _vp::Mat4T

    function OpenGLData(glfw::GLFWData,shrd::SharedData)
        # ! for OpenGLData to succesfully construct, a GLFWData is required, but not stored
        glClearColor(1.0,0.0,1.0,1.0)
        
        myPath = (@__FILE__)
        myPath = myPath[1:(length(myPath) - length("opengl_data.jl"))]
        
        backgroundShader = ShaderProgram(myPath * "Shaders/dflt_bckg.vert", myPath * "Shaders/dflt_bckg.frag",["bCol"])
        combinerShader = ShaderProgram(myPath * "Shaders/dflt_combiner.vert", myPath * "Shaders/dflt_combiner.frag")
        bodyShader = ShaderProgram(myPath * "Shaders/body_3D.vert", myPath * "Shaders/body_3D.frag",["VP"])
        centerShader = ShaderProgram(myPath*"Shaders/center.vert",myPath*"Shaders/center.frag")

        mainAttachements = Dict{GLuint,Texture2D}()
        mainAttachements[GL_COLOR_ATTACHMENT0] = createRGBATexture2D(shrd._width,shrd._height)
        mainAttachements[GL_COLOR_ATTACHMENT1] = createIDTexture2D(shrd._width,shrd._height)
        mainAttachements[GL_DEPTH_ATTACHMENT] = createDepthTexture2D(shrd._width,shrd._height)
        mainFBO = FrameBuffer(mainAttachements)
        
        dummyBufferArray = BufferArray(Vec3,GL_STATIC_DRAW,getAPlane())
        centerBufferArray = BufferArray(Vec3,GL_STATIC_DRAW,Vector{Vec3T{Float32}}([Vec3T{Float32}(0.0,0.0,-1.0)]))
        glEnable(GL_DEPTH_TEST)
        glDepthFunc(GL_LEQUAL)
        
        glEnable(GL_CULL_FACE)
        glCullFace(GL_BACK)
        
        glPolygonMode(GL_BACK,GL_LINE)

        #glEnable(GL_PROGRAM_POINT_SIZE)
        #glDisable(GL_POINT_SMOOTH)
        #glEnable(GL_POINT_SPRITE)

        renderOffices = Dict{DataType,Vector{<:RenderEmployee}}()
        updateMeQueue = Queue{RenderEmployee}()
        
        p = perspective(Float32(70.0),Float32(shrd._width/shrd._height),Float32(0.01),Float32(100.0))
        l = lookat(Vec3T{Float32}(0.0,-5.0,0.0),Vec3T{Float32}(0.0,0.0,0.0),Vec3T{Float32}(0.0,0.0,1.0))
        vp = p * l 
        
        new(shrd,renderOffices,updateMeQueue,
            combinerShader,backgroundShader,bodyShader,centerShader,
            mainAttachements[GL_COLOR_ATTACHMENT0],mainAttachements[GL_COLOR_ATTACHMENT1],
            mainAttachements[GL_DEPTH_ATTACHMENT],
            mainFBO,
            dummyBufferArray,centerBufferArray,
            0,
            Vec3(0.73,0.73,0.73),
            vp)
    end
end

function checkErrors(self::OpenGLData)
    # TODO: Make checkErrors prettier
    opengl_error = glGetError()
    if opengl_error != GL_NO_ERROR
        while (opengl_error != GL_NO_ERROR)
            println(string(opengl_error))
            #println(self._index)
            

            #opengl_error = glGetError()
            #if 1282 == GL_INVALID_OPERATION
            #    println("lols")
            #end
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

function update!(self::OpenGLData)
    checkErrors(self)
    self._index += 1
    while !isempty(self._updateMeQueue)
        employee = dequeue!(self._updateMeQueue)
        sanitize!(employee)
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
    
    for employee in self._renderOffices[Movable_Limited_Employee]
        draw!(employee)
    end

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
        for employee in office
            destroy!(employee) 
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