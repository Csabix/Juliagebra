using DataStructures

@kwdef mutable struct QueueLock
    _locked::Bool=false
end

abstract type QueueLockDNAAble end

_QueueLock_(self::QueueLockDNAAble)::QueueLock = error("Define _QueueLock_ for children!")


function enqueue!(queue::Queue{T}, item::T) where T<:QueueLockDNAAble
    ql = _QueueLock_(item)
    if(!ql._locked)
        DataStructures.enqueue!(queue,item)
        ql._locked = true
    end
end

function dequeue!(queue::Queue{T})::T where T<:QueueLockDNAAble
    item = DataStructures.dequeue!(queue)
    ql = _QueueLock_(item)
    ql._locked = false
    return item
end

abstract type FourWheel <: QueueLockDNAAble end

mutable struct Car <: FourWheel    
    name::String
    _ql::QueueLock
    
    function Car(name::String)
        new(name,QueueLock())
    end
end

_QueueLock_(self::Car)::QueueLock = return self._ql


