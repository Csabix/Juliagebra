# ? ---------------------------------
# ! RendererDNA
# ? ---------------------------------

mutable struct Renderer{T<:RenderedAlgebraDNA} <:QueueLockDNA
    _context::OpenGLData
    _queueLock::QueueLock
    
    _algebras::Vector{T}
    _flaggedQueue::Queue{T}
    _flaggedAsNewQueue::Queue{T}

    function Renderer{T}(context::OpenGLData) where {T<:RenderedAlgebraDNA}
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


function flag!(self::RenderedAlgebraDNA)
    r = _RenderedAlgebra_(self)._renderer
    senqueue!(_Renderer_(r)._flaggedQueue,self)
    senqueue!(_Renderer_(r)._context._updateMeQueue,r)
end 

function flagAsNew!(self::RenderedAlgebraDNA)
    r = _RenderedAlgebra_(self)._renderer
    senqueue!(_Renderer_(r)._flaggedAsNewQueue,self)
    senqueue!(_Renderer_(r)._context._updateMeQueue,r)
end

function assignPlan!(self::RendererDNA{T},plan::PlanDNA)::T where {T<:RenderedAlgebraDNA}
    newAlgebra = plan2Algebra(self,plan)
    _Plan_(plan)._algebra = newAlgebra

    push!(_Renderer_(self)._algebras,newAlgebra)
    flagAsNew!(newAlgebra)
    
    return newAlgebra
end

added!(self::RendererDNA{T},item::T) where {T<:RenderedAlgebraDNA}  = error("Missing func!")
addedUpload!(self::RendererDNA)                             = error("Missing func!")
sync!(self::RendererDNA{T},item::T) where {T<:RenderedAlgebraDNA}   = error("Missing func!")
syncUpload!(self::RendererDNA)                              = error("Missing func!")
draw!(self::RendererDNA,vp,selectedID,pickedID)             = error("Missing func!")
destroy!(self::RendererDNA)                       = error("Missing \"destroy!\" func for instance of RendererDNA")
(plan2Algebra(self::RendererDNA{T},plan::PlanDNA)::T) where {T<:RenderedAlgebraDNA} = error("Missing func for $(typeof(self)) - $(typeof(plan))!")
recruit!(self::OpenGLData, plan::PlanDNA)::AlgebraDNA       = error("Missing func!")