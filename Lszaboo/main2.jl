include("QuickWindow/QuickWindow.jl")
using .QuickWindow

winMan = WindowManager{GLFWBackend,OpenGLAccelerator}()

mainLoop!(winMan)
