
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

    #redTask = Threads.@spawn begin
    #    startConstructor(callback)
    #end 
    
    greenTask = ThreadPinning.@spawnat 1 begin
        startOpengl()
    end

    #greenTask = Task() do 
    #    startOpengl()
    #end
    redTask = ThreadPinning.@spawnat 2 begin
        startConstructor(callback)
    end

    #redTask.sticky = false
    #Base.Threads._spawn_set_thrpool(redTask,:default)

    

    #schedule(greenTask)
    #schedule(redTask)

    #wait(greenTask)
    #wait(redTask)
    
    return greenTask
    println("Main Thread ended!")
end