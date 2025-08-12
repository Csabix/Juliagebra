using DataStructures

include("../../Prototype/source/abstracts.jl")
include("../../Prototype/source/Helpers/queuelock.jl")
include("../../Prototype/source/Helpers/collector.jl")

struct Apple <: CollectedDNA
    _collected::Collected
    
    function Apple(collector::CollectorDNA{Apple})
        collected = Collected(collector)
        new(collected)
    end
end

_Collected_(self::Apple)::Collected = return self._collected

struct AppleCollector <: CollectorDNA{Apple}
    _collector::Collector{Apple}

    function AppleCollector()
        collector = Collector{Apple}()
        new(collector)
    end
end

_Collector_(self::AppleCollector)::Collector{Apple} = return self._collector

appleCollector = AppleCollector()

apple = Apple(appleCollector)

println("$(isFullyConstructed(apple))")
add!!(appleCollector,apple)
println("$(isFullyConstructed(apple))")
