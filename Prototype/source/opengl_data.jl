
# * iter on employees to check changes
# * iter on opengldata for rendering

mutable struct OpenGLData
    _shrd::SharedData

    # TODO: Change Dictionary to an array. This suggestion might be a microoptimization.
    _renderOffices::Dict{<:DataType,Vector{<:RenderEmployee}}
    _updateMeQueue::Queue{RenderEmployee}
    _combinerShader::ShaderProgram
    _backgroundShader::ShaderProgram
    
    _mainRGBATexture :: Texture22D
    _mainIDTexture :: Texture22D
    _mainDepthTexture :: Texture22D
    _mainFBO :: FrameBuffer
    
    _dummyBuffer :: Buffer
    _dummyVertexArray :: VertexArray
    _index :: Int

    function OpenGLData(glfw::GLFWData,shrd::SharedData)
        # ! for OpenGLData to succesfully construct, a GLFWData is required, but not stored
        glClearColor(1.0,0.0,1.0,1.0)
        
        myPath = (@__FILE__)
        myPath = myPath[1:(length(myPath) - length("opengl_data.jl"))]
        
        backgroundShader = ShaderProgram(myPath * "shaders/dflt_bckg.vert", myPath * "shaders/dflt_bckg.frag")
        combinerShader = ShaderProgram(myPath * "shaders/dflt_combiner.vert", myPath * "shaders/dflt_combiner.frag")

        mainAttachements = Dict{GLuint,Texture22D}()
        mainAttachements[GL_COLOR_ATTACHMENT0] = createRGBATexture2D(shrd._width,shrd._height)
        mainAttachements[GL_COLOR_ATTACHMENT1] = createIDTexture2D(shrd._width,shrd._height)
        mainAttachements[GL_DEPTH_ATTACHMENT] = createDepthTexture2D(shrd._width,shrd._height)
        mainFBO = FrameBuffer(mainAttachements)
        
        dummyBuffer = Buffer()
        # ! This upload! causes an opengl error. MUST FIX!
        upload!(dummyBuffer,[Vec3(0.0,0.0,0.0)])
        dummyVertexArray = VertexArray()
        activate(dummyVertexArray)
        vertexAttribs(Vec3)

        

        renderOffices = Dict{DataType,Vector{<:RenderEmployee}}()
        updateMeQueue = Queue{RenderEmployee}()
        
        new(shrd,renderOffices,updateMeQueue,combinerShader,backgroundShader,
            mainAttachements[GL_COLOR_ATTACHMENT0],mainAttachements[GL_COLOR_ATTACHMENT1],
            mainAttachements[GL_DEPTH_ATTACHMENT],
            mainFBO,
            dummyBuffer,dummyVertexArray,
            0)
    end
end

# TODO: Clean checkErrors, so that it's prettier

function checkErrors(self::OpenGLData)
    opengl_error = glGetError()
    while (opengl_error != GL_NO_ERROR)
        println(self._index)
        println(string(opengl_error))
        
        opengl_error = glGetError()
        #if 1282 == GL_INVALID_OPERATION
        #    println("lols")
        #end
    end

end

function update!(self::OpenGLData)
    checkErrors(self)
    self._index += 1
    while !isempty(self._updateMeQueue)
        employee = dequeue!(self._updateMeQueue)
        sanitize!(employee)
    end
    glEnable(GL_DEPTH_TEST)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    # * All the buffers are up to date at this point.

    activate(self._dummyVertexArray)
    activate(self._dummyBuffer)
    activate(self._mainFBO)
    activate(self._backgroundShader)

    glDrawArrays(GL_TRIANGLES,0,6)

    glReadBuffer(GL_COLOR_ATTACHMENT1)
    num = Array{UInt32}(undef,1)
    glReadPixels(0, 0, 1, 1, GL_RED_INTEGER, GL_UNSIGNED_INT,num)
    self._shrd._selectedID = num[1]

    disable(self._mainFBO)
    activate(self._combinerShader)
    activate(self._mainRGBATexture,GL_TEXTURE0)

    glDrawArrays(GL_TRIANGLES,0,6)



    
end


function destroy!(self::OpenGLData)
    
    
    
    Gl.destroy!(self._combinerShader)
    Gl.destroy!(self._backgroundShader)
    Gl.destroy!(self._mainFBO)
    Gl.destroy!(self._mainDepthTexture)
    Gl.destroy!(self._mainIDTexture)
    Gl.destroy!(self._mainRGBATexture)
    Gl.destroy!(self._dummyBuffer)
    Gl.destroy!(self._dummyVertexArray)

    
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