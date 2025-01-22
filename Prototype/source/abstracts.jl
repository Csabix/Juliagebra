abstract type Renderers end
abstract type Algebras end
abstract type Plans end

algebra(p::Plans)::Algebras = error("Create \"algebra(self)\" func for Plans")

ID_LOWER_BOUND = 3

@kwdef mutable struct QueueLock
    _locked::Bool=false
end

function lock(self::QueueLock,queue::Queue{T},item::T) where T
    if(!self._locked)
        enqueue!(queue,item)
        self._locked = true
    end
end

function unlock(self::QueueLock)
    self._locked = false
end

