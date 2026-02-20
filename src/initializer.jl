
global implicitApp::Union{App,Nothing} = nothing

function startOpengl()
    println("OpenGL: $(Threads.threadid())")
    play!()
end

function startConstructor(callback)
    println("Constructor: $(Threads.threadid())")
    callback()
end

function Init(callback::Function)
    global implicitApp
    implicitApp = App()

    task = Threads.@spawn begin
        startConstructor(callback)
    end 
    
    startOpengl()
    wait(task)
    println("Main Thread ended!")
end