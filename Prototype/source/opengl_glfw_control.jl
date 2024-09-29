using GLFW
using ModernGL

struct OpenGLGLFWController <: AGraphicsController
    
    _shrd::SharedData
    _GLFWWindow::GLFW.Window

    function OpenGLGLFWController(shrd::SharedData)
        GLFWWindow = GLFW.CreateWindow(shrd.width,shrd.height,shrd.name)
        new(shrd,GLFWWindow)
    end
end

function init!(grc::OpenGLGLFWController)
    GLFW.MakeContextCurrent(grc._GLFWWindow)
    glClearColor(1.0,0.0,1.0,1.0)
end

function update!(grc::OpenGLGLFWController)
    glClear(GL_COLOR_BUFFER_BIT)
    
    GLFW.SwapBuffers(grc._GLFWWindow)
    GLFW.PollEvents()
    grc._shrd.gameOver = GLFW.WindowShouldClose(grc._GLFWWindow)
end

function destroy!(grc::OpenGLGLFWController)
    GLFW.DestroyWindow(grc._GLFWWindow)
end