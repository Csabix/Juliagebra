using DataStructures

@kwdef mutable struct QueueLock
    _locked::Bool=false
end

abstract type QueueLockAble end

_QueueLock_(self::QueueLockAble)::QueueLock = error("Define _QueueLock_ for children!")

function enqueue!(queue::Queue{QueueLockAble}, item::QueueLockAble)
    ql = _QueueLock_(item)
    if(!ql._locked)
        DataStructures.enqueue!(queue,item)
        ql._locked = true
    end
end

function dequeue!(queue::Queue{QueueLockAble})::QueueLockAble
    item = DataStructures.dequeue!(queue)
    ql = _QueueLock_(item)
    ql._locked = false
    return item
end


mutable struct Car <: QueueLockAble    
    name::String
    _ql::QueueLock
    
    function Car(name::String)
        new(name,QueueLock())
    end
end

_QueueLock_(self::Car)::QueueLock = return self._ql


