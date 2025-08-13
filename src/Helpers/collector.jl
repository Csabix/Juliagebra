mutable struct Collector{T<:CollectedDNA}
    _collection::Vector{T}
    _addedQueue::Queue{T}
    _syncQueue::Queue{T}

    function Collector{T}() where {T<:CollectedDNA}
        collection = Vector{T}()
        addedQueue = Queue{T}()
        syncQueue = Queue{T}()
        new(collection,addedQueue,syncQueue)
    end
end

mutable struct Collected <: QueueLockDNA
    _queueLock::QueueLock
    _collector::Union{CollectorDNA,Nothing}
    _collectorID::Int

    function Collected()
        queueLock = QueueLock()
        new(queueLock,nothing,0)
    end
end

_Collected_(self::CollectedDNA)::Collected = error("Missing \"_Collected_\" func for type of \"$(typeof(self))\"!")
_Collector_(self::CollectorDNA)::Collector = error("Missing \"_Collector_\" func for type of \"$(typeof(self))\"!")

_QueueLock_(self::CollectedDNA)::QueueLock = return _Collected_(self)._queueLock

function hasCollector(self::CollectedDNA)
    collected = _Collected_(self)
    id = collected._collectorID
    return id != 0 && 
           _Collector_(collected._collector)._collection[id] === self
end

function add!!(itemCollector::CollectorDNA,item::CollectedDNA)
    collector = _Collector_(itemCollector)
    collected = _Collected_(item)
    
    push!(collector._collection,item)
    collected._collector = itemCollector
    collected._collectorID = length(collector._collection)

    _flag4Add!!(item)
end

function _flag4Add!!(self::CollectedDNA)
    collected = _Collected_(self)
    collector = _Collector_(collected._collector)
    senqueue!(collector._addedQueue,self)
end

function flag4Sync!!(self::CollectedDNA)
    collected = _Collected_(self)
    collector = _Collector_(collected._collector)
    senqueue!(collector._syncQueue,self)
end

function update!!(self::CollectorDNA)
    collector = _Collector_(self)
    
    if !isempty(collector._addedQueue)
        while !isempty(collector._addedQueue)
            item = sdequeue!(collector._addedQueue)
            added!(self,item)
        end
        addedAll!(self)
    end
    
    if !isempty(collector._syncQueue)
        while !isempty(collector._syncQueue)
            item = sdequeue!(collector._syncQueue)
            sync!(self,item)
        end
        syncAll!(self)
    end
end

added!(itemCollector::CollectorDNA,item::CollectedDNA) = error("Missing \"added!\" func for types of (\"$(typeof(itemCollector))\",\"$(typeof(item))\")!")
sync!(itemCollector::CollectorDNA,item::CollectedDNA) = error("Missing \"sync!\" func for types of (\"$(typeof(itemCollector))\",\"$(typeof(item))\")!")
addedAll!(self::CollectorDNA) = error("Missing \"addedAll!\" func for type of \"$(typeof(self))\"!")
syncAll!(self::CollectorDNA) = error("Missing \"syncAll!\" func for types of \"$(typeof(self))\"!")
