mutable struct GLFWData

    _shrd::SharedData
    _window::GLFW.Window
    _glfwEQ::GLFWEventQueue

    function GLFWData(shrd::SharedData)
        window = GLFW.CreateWindow(shrd._width,shrd._height,shrd._name)
    
        if window == C_NULL
            error("GLFW window creation failed.")
        end
    
        GLFW.MakeContextCurrent(window)
        glfwEQ = GLFWEventQueue(window)

        new(shrd,window,glfwEQ)
    end
end


destroy!(glfw::GLFWData) = GLFW.DestroyWindow(glfw._window)