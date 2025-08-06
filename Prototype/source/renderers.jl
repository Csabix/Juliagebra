# ? ---------------------------------
# ! RendererDNA
# ? ---------------------------------

mutable struct Renderer{T<:RenderedDependentDNA} <:QueueLockDNA
    _context::OpenGLData
    _queueLock::QueueLock
    
    _dependents::Vector{T}
    _flaggedQueue::Queue{T}
    _flaggedAsNewQueue::Queue{T}

    function Renderer{T}(context::OpenGLData) where {T<:RenderedDependentDNA}
        new{T}(context,QueueLock(),Vector{T}(),Queue{T}(),Queue{T}())
    end
end

_Renderer_(self::RendererDNA)::Renderer  = error("Missing \"_Renderer_\" func for instance of RendererDNA")
_QueueLock_(self::RendererDNA)::QueueLock = return _Renderer_(self)._queueLock


function update!(self::RendererDNA)
    r = _Renderer_(self)
    
    if !isempty(r._flaggedAsNewQueue)
        while !isempty(r._flaggedAsNewQueue)
            dependent = sdequeue!(r._flaggedAsNewQueue)
            added!(self,dependent)
        end
        addedUpload!(self)
    end
    
    while !isempty(r._flaggedQueue)
        dependent = sdequeue!(r._flaggedQueue)
        sync!(self,dependent)
    end
    syncUpload!(self)
end


function flag!(self::RenderedDependentDNA)
    r = _RenderedDependent_(self)._renderer
    senqueue!(_Renderer_(r)._flaggedQueue,self)
    senqueue!(_Renderer_(r)._context._updateMeQueue,r)
end 

function flagAsNew!(self::RenderedDependentDNA)
    r = _RenderedDependent_(self)._renderer
    senqueue!(_Renderer_(r)._flaggedAsNewQueue,self)
    senqueue!(_Renderer_(r)._context._updateMeQueue,r)
end

function add!!(self::RendererDNA{T},dependent::T) where {T<:RenderedDependentDNA}
    push!(_Renderer_(self)._dependents,dependent)
    _RenderedDependent_(dependent)._rendererID = length(_Renderer_(self)._dependents)
    flagAsNew!(dependent)
end

function SingleRendererTactic(self::OpenGLData,t::Type{T})::T where T<:RendererDNA
    myVector = get!(self._renderOffices,T,Vector{T}())
    
    if(length(myVector)!=1)
        push!(myVector,T(self))
    end

    return myVector[1]
end

added!(self::RendererDNA{T},item::T) where {T<:RenderedDependentDNA}  = error("Missing func!")
addedUpload!(self::RendererDNA)                             = error("Missing func!")
sync!(self::RendererDNA{T},item::T) where {T<:RenderedDependentDNA}   = error("Missing func!")
syncUpload!(self::RendererDNA)                              = error("Missing func!")
draw!(self::RendererDNA,vp,selectedID,pickedID)             = error("Missing func!")
destroy!(self::RendererDNA)                       = error("Missing \"destroy!\" func for instance of RendererDNA")
(plan2Dependent(self::RendererDNA{T},plan::PlanDNA)::T) where {T<:RenderedDependentDNA} = error("Missing func for $(typeof(self)) - $(typeof(plan))!")
recruit!(self::OpenGLData, plan::PlanDNA)::DependentDNA       = error("Missing func!")