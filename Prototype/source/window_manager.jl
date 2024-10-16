#the manager's logic is defined here, who manages the logic and graphics for juliagebra.

mutable struct Manager

    _shrd::SharedData
    _glfw::Union{GLFWData,Nothing}
    _opengl::Union{OpenGLData,Nothing}
    _windowCreated::Bool
    _algebra::AlgebraLogic
    _renderBoss::RenderBoss

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
        renderBoss = RenderBoss()

        new(shrd,glfw,opengl,windowCreated,algebra,renderBoss)
    end
end

#@connect JuliAgebra.Manager JuliAgebra.Manager._renderBoss JuliAgebra.submit!

function submit!(m::Manager,plan::RenderPlan)
    submit!(m._renderBoss,plan)
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
export play!
export submit!

