#the manager's logic is defined here, who manages the logic and graphics for juliagebra.
#also the data which is shared between the logic and graphics is defined here as well.

abstract type ALogicsController end
abstract type AGraphicsController end

mutable struct SharedData
    name::String
    width::Int
    height::Int
    gameOver::Bool

    function SharedData(name::String,width::Int,height::Int)
        new(name,width,height,false)
    end

end

struct Manager{LogicsT<:ALogicsController,GraphicsT<:AGraphicsController}
    
    _shrd::SharedData
    _loc::LogicsT
    _grc::GraphicsT
    

    function Manager{LogicsT, GraphicsT}(
        name::String="Unnamed Window",
        width::Int=640,
        height::Int=480
        ) where {LogicsT<:ALogicsController,GraphicsT<:AGraphicsController}

        shrd = SharedData(name,width,height)
        loc = LogicsT(shrd)
        grc = GraphicsT(shrd)

        new(shrd,loc,grc)
    end
end

function run!(m::Manager)
    init!(m._loc)
    init!(m._grc)
    while(!m._shrd.gameOver)
        update!(m._grc)
        update!(m._loc)
    end
    destroy!(m._loc)
    destroy!(m._grc)
end

export Manager
export run!

