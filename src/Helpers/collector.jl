

mutable struct Collector{T}
    _collection::Vector{T}
    _addedQueue::Queue{T}
    _syncQueue::Queue{T}

    function Collector{T}() where {T}
        collection = Vector{T}()
        addedQueue = Queue{T}()
        syncQueue = Queue{T}()
        new(collection,addedQueue,syncQueue)
    end
end

_Collector_(self::CollectorDNA)::Collector = error("Missing \"_Collector_\" func for type of \"$(typeof(self))\"!")

mutable struct Collected <: QueueLockDNA
    _queueLock::QueueLock
    _collector::Union{CollectorDNA,CollectedCollectorDNA,Nothing} # TODO: make Collected a generic, on _collector, so Collected{T}
    _collectorID::Int

    function Collected()
        queueLock = QueueLock()
        new(queueLock,nothing,0)
    end
end

_Collected_(self::CollectedDNA)::Collected = error("Missing \"_Collected_\" func for type of \"$(typeof(self))\"!")
_QueueLock_(self::CollectedDNA)::QueueLock = return _Collected_(self)._queueLock

mutable struct CollectedCollector{T} <: QueueLockDNA
    _collected::Collected
    _collector::Collector
    
    function CollectedCollector{T}() where {T}
        new(Collected(),Collector{T}())
    end
end

_CollectedCollector_(self::CollectedCollectorDNA)::CollectedCollector = error("Missing \"_CollectedCollector_\" func for type of \"$(typeof(self))\"!")
_Collected_(self::CollectedCollectorDNA)::Collected = return _CollectedCollector_(self)._collected
_Collector_(self::CollectedCollectorDNA)::Collector = return _CollectedCollector_(self)._collector
_QueueLock_(self::CollectedCollectorDNA)::QueueLock = return _Collected_(self)._queueLock

hasCollector(self::CollectedDNA) = _hasCollector(self)
hasCollector(self::CollectedCollectorDNA) = _hasCollector(self)
function _hasCollector(self)
    collected = _Collected_(self)
    id = collected._collectorID
    return id != 0 && 
           _Collector_(collected._collector)._collection[id] === self
end

add!!(itemCollector::CollectorDNA,item::CollectedDNA) = _add!!(itemCollector,item)
add!!(itemCollector::CollectedCollectorDNA,item::CollectedDNA) = _add!!(itemCollector,item)
add!!(itemCollector::CollectorDNA,item::CollectedCollectorDNA) = _add!!(itemCollector,item)
add!!(itemCollector::CollectedCollectorDNA,item::CollectedCollectorDNA) = _add!!(itemCollector,item)
function _add!!(itemCollector,item)
    collector = _Collector_(itemCollector)
    collected = _Collected_(item)
    
    push!(collector._collection,item)
    collected._collector = itemCollector
    collected._collectorID = length(collector._collection)

    flag4Add!!(item)
end

flag4Add!!(self::CollectedDNA) = _flag4Add!!(self)
flag4Add!!(self::CollectedCollectorDNA) = _flag4Add!!(self)
function _flag4Add!!(self)
    collected = _Collected_(self)
    collector = _Collector_(collected._collector)
    senqueue!(collector._addedQueue,self)
end

flag4Sync!!(self::CollectedDNA) = _flag4Sync!!(self)
flag4Sync!!(self::CollectedCollectorDNA) = _flag4Sync!!(self)
function _flag4Sync!!(self)
    collected = _Collected_(self)
    collector = _Collector_(collected._collector)
    senqueue!(collector._syncQueue,self)
end

update!!(self::CollectorDNA) = _update!!(self)
update!!(self::CollectedCollectorDNA) = _update!!(self)
function _update!!(self)
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

added!(itemCollector::CollectorDNA{T},item::T) where T = error("Missing \"added!\" func for types of (\"$(typeof(itemCollector))\",\"$(typeof(item))\")!")
sync!(itemCollector::CollectorDNA{T},item::T) where T = error("Missing \"sync!\" func for types of (\"$(typeof(itemCollector))\",\"$(typeof(item))\")!")
addedAll!(self::CollectorDNA) = error("Missing \"addedAll!\" func for type of \"$(typeof(self))\"!")
syncAll!(self::CollectorDNA) = error("Missing \"syncAll!\" func for types of \"$(typeof(self))\"!")

added!(itemCollector::CollectedCollectorDNA{T},item::T) where T = error("Missing \"added!\" func for types of (\"$(typeof(itemCollector))\",\"$(typeof(item))\")!")
sync!(itemCollector::CollectedCollectorDNA{T},item::T) where T = error("Missing \"sync!\" func for types of (\"$(typeof(itemCollector))\",\"$(typeof(item))\")!")
addedAll!(self::CollectedCollectorDNA) = error("Missing \"addedAll!\" func for type of \"$(typeof(self))\"!")
syncAll!(self::CollectedCollectorDNA) = error("Missing \"syncAll!\" func for types of \"$(typeof(self))\"!")