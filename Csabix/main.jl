using ImGuiGLFWBackend
using ImGuiGLFWBackend.LibCImGui
using ImGuiGLFWBackend.LibGLFW
using ImGuiOpenGLBackend
using ImGuiOpenGLBackend.ModernGL
include("setuputils.jl")
include("events.jl")
include("gl.jl")
include("Cameras.jl")
include("app.jl")
using .Events
using .App

function main()
    imgui_ctx = igCreateContext(C_NULL)
    window_ctx = ImGuiGLFWBackend.create_context()
    window = ImGuiGLFWBackend.get_window(window_ctx)
    gl_ctx = ImGuiOpenGLBackend.create_context()
    setGlDebugCallback(window,gl_ctx)
    ImGuiGLFWBackend.init(window_ctx)
    ImGuiOpenGLBackend.init(gl_ctx)
    
    event_queue = EventQueue(window) # can only make one

    app = AppState()
    init!(app)

    while glfwWindowShouldClose(window) == GLFW_FALSE
        glfwPollEvents()
        while true
            ev = poll_event!(event_queue)
            if isnothing(ev); break; end
            # todo check imgui
            event!(app,ev)
        end 

        ImGuiOpenGLBackend.new_frame(gl_ctx)
        ImGuiGLFWBackend.new_frame(window_ctx)
        
        render!(app)

        igNewFrame()
        #igShowDemoWindow(Ref(true))
        igShowMetricsWindow(Ref(true))
        igRender()
        ImGuiOpenGLBackend.render(gl_ctx)
        glfwSwapBuffers(window)
    end
    ImGuiOpenGLBackend.shutdown(gl_ctx)
    ImGuiGLFWBackend.shutdown(window_ctx)
    igDestroyContext(imgui_ctx)
    glfwDestroyWindow(window)
end

main()