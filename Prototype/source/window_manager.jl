#the manager's logic is defined here, who manages the logic and graphics for juliagebra.

mutable struct Manager

    _shrd::SharedData
    _glfw::Union{GLFWData,Nothing}
    _opengl::Union{OpenGLData,Nothing}
    _windowCreated::Bool
    _algebra::AlgebraLogic
    _plans::Queue{RenderPlan}

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
        plans = Queue{RenderPlan}()

        new(shrd,glfw,opengl,windowCreated,algebra,plans)
    end
end

function submit!(self::Manager,plan::RenderPlan)
    enqueue!(self._plans,plan)    
end

function play!(self::Manager)
    
    init!(self)
    while(!self._shrd._gameOver)
        update!(self._algebra)
        update!(self._opengl)
    
        GLFW.SwapBuffers(self._glfw._window)
        GLFW.PollEvents()
        ev = poll_event!(self._glfw._glfwEQ)
        while(!isnothing(ev))
            #println(string(ev))
            ev = poll_event!(self._glfw._glfwEQ)
        end
        
        while(!isempty(self._plans))
            println("Processing a Plan!")
            hire_for_plan!(self._opengl,dequeue!(self._plans))
        end

        self._shrd._gameOver = GLFW.WindowShouldClose(self._glfw._window)

    end
    destroy!(self)
    
end


function init!(self::Manager)
    if self._windowCreated
        error("Window is already created, can't init! again.")
    end
    


    self._glfw = GLFWData(self._shrd)
    self._opengl = OpenGLData(self._glfw,self._shrd)
    
    self._windowCreated = true

    init!(self._algebra)
end

function destroy!(self::Manager)
    if !self._windowCreated
        error("No window created, thus, can't destroy!.")
    end
    
    destroy!(self._glfw)
    destroy!(self._opengl)
    destroy!(self._algebra)
end

export Manager
export play!
export submit!

