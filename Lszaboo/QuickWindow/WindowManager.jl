abstract type AWindowBackend end
abstract type AGraphicsAccelerator end

mutable struct WindowData
    shouldRun❓::Bool
    name🪪::String
    width⏩::Int
    height⏫::Int
    clearColor::Vector{Float64}
end

struct WindowManager{backendT<:AWindowBackend,graphicsT<:AGraphicsAccelerator}

    _data📚 :: WindowData
    _windowBackend🔩::backendT
    _graphicsAccelerator🚀::graphicsT

    function WindowManager{backendT, graphicsT}(
        name🪪::String="Unnamed Window",
        width⏩::Int=640,
        height⏫::Int=480) where {backendT<:AWindowBackend,graphicsT<:AGraphicsAccelerator}

        data📚 = WindowData(true,name🪪,width⏩,height⏫,[1.0,0.0,1.0,1.0])
        windowBackend🔩 = backendT(data📚)
        graphicsAccelerator🚀 = graphicsT(data📚)
        new(data📚,windowBackend🔩,graphicsAccelerator🚀)
    end
end

function mainLoop!(winMan::WindowManager)
    init!(winMan._windowBackend🔩)
    init!(winMan._graphicsAccelerator🚀)
    while(winMan._data📚.shouldRun❓)
        update!(winMan._windowBackend🔩)
        update!(winMan._graphicsAccelerator🚀)
    end
    destroy!(winMan._windowBackend🔩)
end