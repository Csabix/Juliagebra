# ? ---------------------------------
# ! RendererDNA
# ? ---------------------------------

mutable struct Renderer{T<:AlgebraDNA} <:QueueLockDNA
    _context::OpenGLData
    _queueLock::QueueLock
    
    _algebras::Vector{T}
    _flaggedQueue::Queue{T}
    _flaggedAsNewQueue::Queue{T}

    function Renderer{T}(context::OpenGLData) where {T<:AlgebraDNA}
        new{T}(context,QueueLock(),Vector{T}(),Queue{T}(),Queue{T}())
    end
end

_Renderer_(self::RendererDNA)::Renderer  = error("Missing \"_Renderer_\" func for instance of RendererDNA")
_QueueLock_(self::RendererDNA)::QueueLock = return _Renderer_(self)._queueLock


function update!(self::RendererDNA)
    r = _Renderer_(self)
    
    if !isempty(r._flaggedAsNewQueue)
        while !isempty(r._flaggedAsNewQueue)
            algebra = sdequeue!(r._flaggedAsNewQueue)
            added!(self,algebra)
        end
        addedUpload!(self)
    end
    
    while !isempty(r._flaggedQueue)
        algebra = sdequeue!(r._flaggedQueue)
        sync!(self,algebra)
    end
    syncUpload!(self)
end


function flag!(self::AlgebraDNA)
    r = _Algebra_(self)._renderer
    senqueue!(_Renderer_(r)._flaggedQueue,self)
    senqueue!(_Renderer_(r)._context._updateMeQueue,r)
end 

function flagAsNew!(self::AlgebraDNA)
    r = _Algebra_(self)._renderer
    senqueue!(_Renderer_(r)._flaggedAsNewQueue,self)
    senqueue!(_Renderer_(r)._context._updateMeQueue,r)
end

function assignPlan!(self::RendererDNA{T},plan::PlanDNA)::T where {T<:AlgebraDNA}
    newAlgebra = plan2Algebra(self,plan)
    _Plan_(plan)._algebra = newAlgebra

    push!(_Renderer_(self)._algebras,newAlgebra)
    flagAsNew!(newAlgebra)
    
    return newAlgebra
end


sync!(self::RendererDNA{T},item::T) where {T<:AlgebraDNA}   = error("Missing func!")
upload!(self::RendererDNA)                                  = error("Missing func!")
draw!(self::RendererDNA)                          = error("Missing \"draw!\" func for instance of RendererDNA")
destroy!(self::RendererDNA)                       = error("Missing \"destroy!\" func for instance of RendererDNA")
(plan2Algebra(self::RendererDNA{T},plan::PlanDNA)::T) where {T<:AlgebraDNA} = error("Missing func!")