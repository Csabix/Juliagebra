
function MouseMotionCallback(window::Ptr{GLFWwindow}, xpos::Cdouble, ypos::Cdouble)::Cvoid
    if !unsafe_load(igGetIO().WantCaptureMouse)
        #mouseMove(Renderer.getCamera(),xpos,ypos)
        Renderer.mouseMove(window,xpos,ypos);
    end
    return nothing
end

function MouseButtonCallback(window::Ptr{GLFWwindow}, key::Cint, action::Cint, mods::Cint)::Cvoid
    if action != GLFW_REPEAT && !unsafe_load(igGetIO().WantCaptureMouse)
        #mouseButton(Renderer.getCamera(),key,action,mods)
        Renderer.mouseButton(window,key,action,mods)
    end
    return nothing
end

function KeyCallback(window::Ptr{GLFWwindow}, key::Cint, scancode::Cint, action::Cint, mods::Cint)::Cvoid
    if action != GLFW_REPEAT && !unsafe_load(igGetIO().WantCaptureKeyboard)
        keyboardButton(Renderer.getCamera(),key,action,mods)
        if action == GLFW_PRESS
            if key == GLFW_KEY_ESCAPE
                glfwSetWindowShouldClose(window,true)
            else
                Renderer.keyDown(key,mods)
            end
        end
    end
    return nothing
end

function ScrollCallback(window::Ptr{GLFWwindow}, xoffset::Cdouble, yoffset::Cdouble)::Cvoid

    return nothing
end

function CharCallback(window::Ptr{GLFWwindow}, x::Cuint)::Cvoid
    
    return nothing
end

function MonitorCallback(monitor::Ptr{GLFWmonitor}, x::Cint)::Cvoid

    return nothing
end

function WindowCloseCallback(window::Ptr{GLFWwindow})::Cvoid

    return nothing
end

function WindowPosCallback(window::Ptr{GLFWwindow}, x::Cint, y::Cint)::Cvoid

    return nothing
end

function WindowSizeCallback(window::Ptr{GLFWwindow}, x::Cint, y::Cint)::Cvoid
    Renderer.resize(x,y);
    resizeWindow(Renderer.getCamera(),x,y)
    return nothing
end


function setGlfwCallbacks()
    glfwSetCursorPosCallback(window, @cfunction(MouseMotionCallback, Cvoid, (Ptr{GLFWwindow}, Cdouble, Cdouble)))
    glfwSetMouseButtonCallback(window, @cfunction(MouseButtonCallback, Cvoid, (Ptr{GLFWwindow}, Cint, Cint, Cint)))
    glfwSetKeyCallback(window, @cfunction(KeyCallback, Cvoid, (Ptr{GLFWwindow}, Cint, Cint, Cint, Cint)))
    # glfwSetScrollCallback(window, @cfunction(ScrollCallback, Cvoid, (Ptr{GLFWwindow}, Cdouble, Cdouble)))
    # glfwSetCharCallback(window, @cfunction(CharCallback, Cvoid, (Ptr{GLFWwindow}, Cuint)))
    # glfwSetWindowCloseCallback(window, @cfunction(WindowCloseCallback, Cvoid, (Ptr{GLFWwindow},)))
    # glfwSetWindowPosCallback(window, @cfunction(WindowPosCallback, Cvoid, (Ptr{GLFWwindow}, Cint, Cint)))
    glfwSetWindowSizeCallback(window, @cfunction(WindowSizeCallback, Cvoid, (Ptr{GLFWwindow}, Cint, Cint)))
end