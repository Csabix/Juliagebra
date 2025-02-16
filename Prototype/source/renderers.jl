# ? ---------------------------------
# ! €Renderer
# ? ---------------------------------

mutable struct Renderer{T<:€Algebra} <:€QueueLock
    _context::OpenGLData
    _queueLock::QueueLock
    
    _algebraQueue::Queue{T}
    
    function Renderer{T}(context::OpenGLData) where {T<:€Algebra}
        new{T}(context,QueueLock(),Queue{T}())
    end
end


_Renderer_(self::€Renderer)::Renderer  = error("Missing \"_Renderer_\" func for instance of €Renderer")
_QueueLock_(self::€Renderer)::QueueLock = return _Renderer_(self)._queueLock

update!(self::€Renderer)                        = error("Missing \"update!\" func for instance of €Renderer")
draw!(self::€Renderer)                          = error("Missing \"draw!\" func for instance of €Renderer")
draw!(self::€Renderer,vp,selectedID,pickedID)   = error("Missing \"draw!\" func for instance of €Renderer")
destroy!(self::€Renderer)                       = error("Missing \"destroy!\" func for instance of €Renderer")

function senqueue!(self::€Renderer{T},algebra::T) where T<:€Algebra
    senqueue!(_Renderer_(self)._algebraQueue,algebra)
    senqueue!(self)
end

function senqueue!(self::€Renderer)
    updateMeQueue = _Renderer_(self)._context._updateMeQueue
    senqueue!(updateMeQueue,self)
end