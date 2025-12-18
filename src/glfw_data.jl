mutable struct GLFWData

    _shrd::SharedData
    _window::GLFW.Window

    function GLFWData(shrd::SharedData)
        GLFW.WindowHint(GLFW.DOUBLEBUFFER , 1);
        GLFW.WindowHint(GLFW.DEPTH_BITS, 24);
        GLFW.WindowHint(GLFW.STENCIL_BITS, 8);

        GLFW.WindowHint(GLFW.CONTEXT_VERSION_MAJOR, 4)
        GLFW.WindowHint(GLFW.CONTEXT_VERSION_MINOR, 6)
        GLFW.WindowHint(GLFW.OPENGL_PROFILE, GLFW.OPENGL_CORE_PROFILE);
        
        window = GLFW.CreateWindow(shrd._width,shrd._height,shrd._name)

        if window == C_NULL
            error("GLFW window creation failed.")
        end
        
        GLFW.MakeContextCurrent(window)
        GLFW.SwapInterval(1)

        new(shrd,window)
    end
end

destroy!(glfw::GLFWData) = GLFW.DestroyWindow(glfw._window)
disable_mouse(glfw::GLFWData) = GLFW.SetInputMode(glfw._window, GLFW.CURSOR, GLFW.CURSOR_DISABLED);
enable_mouse(glfw::GLFWData) = GLFW.SetInputMode(glfw._window, GLFW.CURSOR, GLFW.CURSOR_NORMAL);