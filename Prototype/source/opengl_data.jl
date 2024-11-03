
# * iter on employees to check changes
# * iter on opengldata for rendering

mutable struct OpenGLData
    _shrd::SharedData

    # TODO: Change Dictionary to an array. This suggestion might be a microoptimization.
    _renderOffices::Dict{<:DataType,Vector{<:RenderEmployee}}
    _updateMeQueue::Queue{RenderEmployee}
    _combinerShader::ShaderProgram
    _backgroundShader::ShaderProgram
    
    _mainRGBATexture :: Texture2D
    _mainIDTexture :: Texture2D
    _mainDepthTexture :: Texture2D
    _mainFBO :: FrameBuffer
    
    _dummyBuffer :: Buffer
    _dummyVertexArray :: VertexArray
    _index :: Int

    _backgroundCol::Vec3

    function OpenGLData(glfw::GLFWData,shrd::SharedData)
        # ! for OpenGLData to succesfully construct, a GLFWData is required, but not stored
        glClearColor(1.0,0.0,1.0,1.0)
        
        myPath = (@__FILE__)
        myPath = myPath[1:(length(myPath) - length("opengl_data.jl"))]
        
        backgroundShader = ShaderProgram(myPath * "shaders/dflt_bckg.vert", myPath * "shaders/dflt_bckg.frag",["bCol"])
        combinerShader = ShaderProgram(myPath * "shaders/dflt_combiner.vert", myPath * "shaders/dflt_combiner.frag")

        mainAttachements = Dict{GLuint,Texture2D}()
        mainAttachements[GL_COLOR_ATTACHMENT0] = createRGBATexture2D(shrd._width,shrd._height)
        mainAttachements[GL_COLOR_ATTACHMENT1] = createIDTexture2D(shrd._width,shrd._height)
        mainAttachements[GL_DEPTH_ATTACHMENT] = createDepthTexture2D(shrd._width,shrd._height)
        mainFBO = FrameBuffer(mainAttachements)
        
        dummyBuffer = Buffer(GL_STATIC_DRAW)
        upload!(dummyBuffer,getAPlane())
        dummyVertexArray = VertexArray(Vec3)


        

        renderOffices = Dict{DataType,Vector{<:RenderEmployee}}()
        updateMeQueue = Queue{RenderEmployee}()
        
        new(shrd,renderOffices,updateMeQueue,combinerShader,backgroundShader,
            mainAttachements[GL_COLOR_ATTACHMENT0],mainAttachements[GL_COLOR_ATTACHMENT1],
            mainAttachements[GL_DEPTH_ATTACHMENT],
            mainFBO,
            dummyBuffer,dummyVertexArray,
            0,
            Vec3(0.73,0.73,0.73))
    end
end

# TODO: Make checkErrors prettier

function checkErrors(self::OpenGLData)
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
    Gl.resize!(self._mainRGBATexture,width,height)
    Gl.resize!(self._mainIDTexture,width,height)
    Gl.resize!(self._mainDepthTexture,width,height)
end

function readID(self::OpenGLData)
    x = self._shrd._mouseX
    y = self._shrd._mouseY
    width = self._shrd._width
    height = self._shrd._height

    if self._shrd._shouldReadID && x<width && y<height
        glReadBuffer(GL_COLOR_ATTACHMENT1)
        num = Array{UInt32}(undef,1)
        glReadPixels(x, y, 1, 1, GL_RED_INTEGER, GL_UNSIGNED_INT,num)
        self._shrd._selectedID = num[1]
        self._shrd._shouldReadID = false
    end
end

function update!(self::OpenGLData)
    checkErrors(self)
    self._index += 1
    while !isempty(self._updateMeQueue)
        employee = dequeue!(self._updateMeQueue)
        sanitize!(employee)
    end
    #glEnable(GL_DEPTH_TEST)
    #glEnable(GL_BLEND)
    #glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
    #glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    # * All the buffers are up to date at this point.
    
    activate(self._mainFBO)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    
    
    activate(self._dummyVertexArray)
    activate(self._dummyBuffer)
    activate(self._backgroundShader)
    setUniform!(self._backgroundShader,"bCol",self._backgroundCol)  
    
    draw(self._dummyBuffer,GL_TRIANGLES)
    readID(self)

    disable(self._mainFBO)
    activate(self._combinerShader)
    activate(self._mainRGBATexture,GL_TEXTURE0)
    draw(self._dummyBuffer,GL_TRIANGLES)
end


function destroy!(self::OpenGLData)
    Gl.delete!(self._combinerShader)
    Gl.delete!(self._backgroundShader)
    Gl.delete!(self._mainFBO)
    Gl.delete!(self._mainDepthTexture)
    Gl.delete!(self._mainIDTexture)
    Gl.delete!(self._mainRGBATexture)
    Gl.delete!(self._dummyBuffer)
    Gl.delete!(self._dummyVertexArray)
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