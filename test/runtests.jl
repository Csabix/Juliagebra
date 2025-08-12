using Test
import Juliagebra as JLA


@testset "Collectors test" begin
    struct Apple <: JLA.CollectedDNA
    _collected::JLA.Collected
    
        function Apple(collector::JLA.CollectorDNA{Apple})
            collected = JLA.Collected(collector)
            new(collected)
        end
    end

    struct AppleCollector <: JLA.CollectorDNA{Apple}
        _collector::JLA.Collector{Apple}

        function AppleCollector()
            collector = JLA.Collector{Apple}()
            new(collector)
        end
    end

    JLA._Collected_(self::Apple)::JLA.Collected = return self._collected
    JLA._Collector_(self::AppleCollector)::JLA.Collector{Apple} = return self._collector

    appleCollector = AppleCollector()
    apple = Apple(appleCollector)

    @test JLA.isFullyConstructed(apple) == false
    JLA.add!!(appleCollector,apple)
    @test JLA.isFullyConstructed(apple) == true
end

