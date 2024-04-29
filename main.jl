using ImGuiGLFWBackend
using ImGuiGLFWBackend.LibCImGui
using ImGuiGLFWBackend.LibGLFW
using ImGuiOpenGLBackend
using ImGuiOpenGLBackend.ModernGL

include("Renderer.jl")
using .Renderer
using .Renderer.Cameras

# create contexts
imgui_ctx = igCreateContext(C_NULL)
window_ctx = ImGuiGLFWBackend.create_context()
window = ImGuiGLFWBackend.get_window(window_ctx)
gl_ctx = ImGuiOpenGLBackend.create_context()

include("setuputils.jl")

setGlDebugCallback(window,gl_ctx)

init()

include("callbacks.jl")

setGlfwCallbacks()

ImGuiGLFWBackend.init(window_ctx)
ImGuiOpenGLBackend.init(gl_ctx)

while glfwWindowShouldClose(window) == GLFW_FALSE
    glfwPollEvents()
    
    render()

    ImGuiOpenGLBackend.new_frame(gl_ctx)
    ImGuiGLFWBackend.new_frame(window_ctx)
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
