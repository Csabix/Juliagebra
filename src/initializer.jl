
global implicitApp::Union{App,Nothing} = nothing

function Init(callback::Function)
    global implicitApp
    implicitApp = App()
    
    Threads.@spawn begin
        callback()
    end
    
    play!(implicitApp)

end