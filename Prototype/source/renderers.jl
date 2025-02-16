# ? ---------------------------------
# ! RendererDNA
# ? ---------------------------------

mutable struct Renderer{T<:AlgebraDNA} <:QueueLockDNA
    _context::OpenGLData
    _queueLock::QueueLock
    
    _algebraQueue::Queue{T}
    
    function Renderer{T}(context::OpenGLData) where {T<:AlgebraDNA}
        new{T}(context,QueueLock(),Queue{T}())
    end
end


_Renderer_(self::RendererDNA)::Renderer  = error("Missing \"_Renderer_\" func for instance of RendererDNA")
_QueueLock_(self::RendererDNA)::QueueLock = return _Renderer_(self)._queueLock

update!(self::RendererDNA)                        = error("Missing \"update!\" func for instance of RendererDNA")
draw!(self::RendererDNA)                          = error("Missing \"draw!\" func for instance of RendererDNA")
draw!(self::RendererDNA,vp,selectedID,pickedID)   = error("Missing \"draw!\" func for instance of RendererDNA")
destroy!(self::RendererDNA)                       = error("Missing \"destroy!\" func for instance of RendererDNA")

function senqueue!(self::RendererDNA{T},algebra::T) where T<:AlgebraDNA
    senqueue!(_Renderer_(self)._algebraQueue,algebra)
    senqueue!(self)
end

function senqueue!(self::RendererDNA)
    updateMeQueue = _Renderer_(self)._context._updateMeQueue
    senqueue!(updateMeQueue,self)
end