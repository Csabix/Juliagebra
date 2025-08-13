using Test

@testset verbose=true "Collector and Collected Tests" begin
    import Juliagebra as SUT

    mutable struct TestCollected <: SUT.CollectedDNA
        _collected::SUT.Collected

        function TestCollected()
            collected = SUT.Collected()
            new(collected)
        end
    end

    mutable struct TestCollector <: SUT.CollectorDNA{TestCollected}
        _collector::SUT.Collector{TestCollected}
        
        newlyAddedCallNum::Int
        addedCallNum::Int

        newlySyncedCallNum::Int
        syncedCallNum::Int

        newlyAddedItems::Vector{TestCollected}
        newlySyncedItems::Vector{TestCollected}
        addedItems::Vector{TestCollected}
        syncedItems::Vector{TestCollected}
        
        function TestCollector()
            collector = SUT.Collector{TestCollected}()
            new(collector,0,-1,0,-1,
                Vector{TestCollected}(),
                Vector{TestCollected}(),
                Vector{TestCollected}(),
                Vector{TestCollected}()
                )
        end
    end

    SUT._Collected_(self::TestCollected)::SUT.Collected                = return self._collected
    SUT._Collector_(self::TestCollector)::SUT.Collector{TestCollected} = return self._collector

    function SUT.added!(self::TestCollector,item::TestCollected) 
        self.newlyAddedCallNum += 1
        push!(self.newlyAddedItems,item)
    end
    
    function SUT.sync!(self::TestCollector,item::TestCollected) 
        self.newlySyncedCallNum+=1
        push!(self.newlySyncedItems,item)
    end

    function SUT.addedAll!(self::TestCollector) 
        self.addedCallNum = self.newlyAddedCallNum
        self.newlyAddedCallNum = 0
        
        self.addedItems = self.newlyAddedItems
        self.newlyAddedItems = []
    end
    
    function SUT.syncAll!(self::TestCollector) 
        self.syncedCallNum = self.newlySyncedCallNum
        self.newlySyncedCallNum = 0
        
        self.syncedItems = self.newlySyncedItems
        self.newlySyncedItems = []
    end

    @testset "Collected has Collector after add!!" begin
        collector = TestCollector()
        collected = TestCollected()

        @test SUT.hasCollector(collected) == false
        SUT.add!!(collector,collected)
        @test SUT.hasCollector(collected) == true
    end

    @testset "Empty collector after update!" begin
        collector = TestCollector()
        
        SUT.update!!(collector)

        @test collector.addedCallNum == -1
        @test collector.syncedCallNum == -1
        @test isempty(collector.addedItems)
        @test isempty(collector.syncedItems)
    end

    @testset "Collected added! calls on $(itemNum) items added" for itemNum in [1,10]
        collector = TestCollector()
        items = []

        for i in 1:itemNum
            push!(items,TestCollected())
            SUT.add!!(collector,items[i])
        end

        SUT.update!!(collector)

        @test collector.syncedCallNum == -1
        @test collector.addedCallNum == itemNum
        @test isempty(collector.syncedItems)

        for i in 1:itemNum
            @test collector.addedItems[i] === items[i]
            @test isempty(collector.newlyAddedItems)
        end
    end
end

