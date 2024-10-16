mutable struct OpenGLData


    function OpenGLData(glfw::GLFWData)
        #NOTE: for OpenGLData to succesfully construct, a GLFWData is required, but not stored
        glClearColor(1.0,0.0,1.0,1.0)
        new()
    end
end


function destroy!(openglD::OpenGLData)

end