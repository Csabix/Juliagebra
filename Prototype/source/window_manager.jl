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


    function OpenGLData(glfw::GLFWData)
        #NOTE: for OpenGLData to succesfully construct, a GLFWData is required, but not stored
        glClearColor(1.0,0.0,1.0,1.0)
        new()
    end
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

mutable struct Manager

    _shrd::SharedData
    _glfw::Union{GLFWData,Nothing}
    _opengl::Union{OpenGLData,Nothing}
    _windowCreated::Bool
    _algebra::AlgebraLogic
    
    function Manager(
        name::String="Unnamed Window",
        width::Int=640,
        height::Int=480
        )

        shrd = SharedData(name,width,height)
        glfw = nothing
        opengl = nothing
        windowCreated = false
        algebra = AlgebraLogic(shrd)

        new(shrd,glfw,opengl,windowCreated,algebra)
    end
end

function play!(m::Manager)
    
    init!(m)
    while(!m._shrd._gameOver)
        update!(m._algebra)

        glClear(GL_COLOR_BUFFER_BIT)
    
        GLFW.SwapBuffers(m._glfw._window)
        GLFW.PollEvents()
        ev = poll_event!(m._glfw._glfwEQ)
        while(!isnothing(ev))
            println(string(ev))
            ev = poll_event!(m._glfw._glfwEQ)
        end

        m._shrd._gameOver = GLFW.WindowShouldClose(m._glfw._window)

    end
    destroy!(m)
    
end



function init!(m::Manager)
    if m._windowCreated
        error("Window is already created, can't init! again.")
    end
    
    
    m._glfw = GLFWData(m._shrd)
    m._opengl = OpenGLData(m._glfw)
    m._windowCreated = true

    init!(m._algebra)
end

function destroy!(m::Manager)
    if !m._windowCreated
        error("No window created, thus, can't destroy!.")
    end
    
    destroy!(m._glfw)
    destroy!(m._opengl)
    destroy!(m._algebra)
end

export Manager
export show!

