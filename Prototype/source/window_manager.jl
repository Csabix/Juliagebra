#the manager's logic is defined here, who manages the logic and graphics for juliagebra.
#also the data which is shared between the logic and graphics is defined here as well.

using GLFW
using ModernGL

#=
  #####   #        #######  #     #  ######
 #     #  #        #        #  #  #  #     #    ##    #####    ##
 #        #        #        #  #  #  #     #   #  #     #     #  #
 #  ####  #        #####    #  #  #  #     #  #    #    #    #    #
 #     #  #        #        #  #  #  #     #  ######    #    ######
 #     #  #        #        #  #  #  #     #  #    #    #    #    #
  #####   #######  #         ## ##   ######   #    #    #    #    #

=#

mutable struct GLFWData

    _shrd::SharedData
    _window::Union{GLFW.Window,Nothing}
    _windowConstructed::Bool

    function GLFWData(shrd::SharedData)
        new(shrd,nothing,false)
    end
end

function init!(glfwD::GLFWData)
    
    window = GLFW.CreateWindow(glfwD._shrd.width,glfwD._shrd.height,glfwD._shrd.name)
    
    if window == C_NULL
        error("GLFW window creation failed.")
    end

    glfwD._window = window
    glfwD._windowConstructed = true
    GLFW.MakeContextCurrent(glfwD._window)

end

isInited(glfwD::GLFWData)::Bool = glfwD._windowConstructed

function destroy!(glfwD::GLFWData)
    
    if !isInited(glfwD)
        error("GLFWData must be init!-ed before destroy!-ing")
    end

    GLFW.DestroyWindow(glfwD._window)
    glfwD._windowConstructed = false
end

#=
 #######                           #####   #        ######
 #     #  #####   ######  #    #  #     #  #        #     #    ##    #####    ##
 #     #  #    #  #       ##   #  #        #        #     #   #  #     #     #  #
 #     #  #    #  #####   # #  #  #  ####  #        #     #  #    #    #    #    #
 #     #  #####   #       #  # #  #     #  #        #     #  ######    #    ######
 #     #  #       #       #   ##  #     #  #        #     #  #    #    #    #    #
 #######  #       ######  #    #   #####   #######  ######   #    #    #    #    #

=#

mutable struct OpenGLData

end

function init!(openglD::OpenGLData)
    glClearColor(1.0,0.0,1.0,1.0)
end

function destroy!(openglD::OpenGLData)

end

#=
 #     #
 ##   ##    ##    #    #    ##     ####   ######  #####
 # # # #   #  #   ##   #   #  #   #    #  #       #    #
 #  #  #  #    #  # #  #  #    #  #       #####   #    #
 #     #  ######  #  # #  ######  #  ###  #       #####
 #     #  #    #  #   ##  #    #  #    #  #       #   #
 #     #  #    #  #    #  #    #   ####   ######  #    #

=#

struct Manager

    _shrdD::SharedData
    _glfwD::GLFWData
    _openglD::OpenGLData
    _algebra::AlgebraLogic
    
    function Manager(
        name::String="Unnamed Window",
        width::Int=640,
        height::Int=480
        )

        shrd = SharedData(name,width,height)
        glfw = GLFWData(shrd)
        opengl = OpenGLData()
        algebra = AlgebraLogic(shrd)

        new(shrd,glfw,opengl,algebra)
    end
end

function show!(m::Manager)
    
    init!(m)
    while(!m._shrdD.gameOver)
        update!(m._algebra)

        glClear(GL_COLOR_BUFFER_BIT)
    
        GLFW.SwapBuffers(m._glfwD._window)
        GLFW.PollEvents()
        m._shrdD.gameOver = GLFW.WindowShouldClose(m._glfwD._window)

    end
    destroy!(m)
    
end



function init!(m::Manager)
    init!(m._glfwD)
    init!(m._openglD)
    init!(m._algebra)
end

function destroy!(m::Manager)
    destroy!(m._openglD)
    destroy!(m._glfwD)
    destroy!(m._algebra)
end

export Manager
export show!

