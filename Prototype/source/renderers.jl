# ? ---------------------------------
# ! €Renderer
# ? ---------------------------------

mutable struct Renderer <:€QueueLock
    _context::OpenGLData
    _ql::QueueLock

    function Renderer(context::OpenGLData) 
        new(context,QueueLock())
    end
end


_Renderer_(self::€Renderer)::Renderer  = error("Missing \"_Renderer_\" func for instance of €Renderer")
_QueueLock_(self::€Renderer)::QueueLock = return _Renderer_(self)._ql

update!(self::€Renderer)                        = error("Missing \"update!\" func for instance of €Renderer")
draw!(self::€Renderer)                          = error("Missing \"draw!\" func for instance of €Renderer")
draw!(self::€Renderer,vp,selectedID,pickedID)   = error("Missing \"draw!\" func for instance of €Renderer")
destroy!(self::€Renderer)                       = error("Missing \"destroy!\" func for instance of €Renderer")
enqueue!(self::€Renderer,algebra::€Algebra)     = error("Missing \"enqueue!\" func for instance of €Renderer")


function enqueue!(self::€Renderer)
    updateMeQueue = _Renderer_(self)._context._updateMeQueue
    enqueue!(updateMeQueue,self)
end