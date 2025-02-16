# ? ---------------------------------
# ! €QueueLock
# ? ---------------------------------

@kwdef mutable struct QueueLock
    _locked::Bool=false
end

_QueueLock_(self::€QueueLock)::QueueLock = error("Missing \"_QueueLock_\" func for instance of QueueLockS")

function enqueue!(queue::Queue{T}, item::T) where T<:€QueueLock
    ql = _QueueLock_(item)
    if(!ql._locked)
        DataStructures.enqueue!(queue,item)
        ql._locked = true
    end
end

function dequeue!(queue::Queue{T})::T where T<:€QueueLock
    item = DataStructures.dequeue!(queue)
    ql = _QueueLock_(item)
    ql._locked = false
    return item
end