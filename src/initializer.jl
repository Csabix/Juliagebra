
global implicitApp::Union{App,Nothing} = nothing

function Init(callback::Function)
    global implicitApp
    implicitApp = App()
    
    
    worker = Threads.@spawn :default callback()
   
    play!(implicitApp,worker)

    println("Main Thread ended!")
end