# ? ---------------------------------
# ! QueueLockDNA
# ? ---------------------------------

@kwdef mutable struct QueueLock
    _locked::Bool=false
end

function _QueueLock_(self::T)::QueueLock where T<:QueueLockDNA
    error("Missing \"_QueueLock_\" func for instance of $(string(typeof(self)))")
end

function senqueue!(queue::Queue{T}, item::T) where T<:QueueLockDNA
    ql = _QueueLock_(item)
    if(!ql._locked)
        enqueue!(queue,item)
        ql._locked = true
    end
end

function sdequeue!(queue::Queue{T})::T where T<:QueueLockDNA
    item = dequeue!(queue)
    ql = _QueueLock_(item)
    ql._locked = false
    return item
end