
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
        
        addedCallNum::Int
        addedAllCallNum::Int
        addedItems::Vector{TestCollected}
        
        syncedCallNum::Int
        syncedAllCallNum::Int
        syncedItems::Vector{TestCollected}
        
        function TestCollector()
            collector = SUT.Collector{TestCollected}()
            new(collector,
                0,0,Vector{TestCollected}(),
                0,0,Vector{TestCollected}()
                )
        end
    end

    SUT._Collected_(self::TestCollected)::SUT.Collected                = return self._collected
    SUT._Collector_(self::TestCollector)::SUT.Collector{TestCollected} = return self._collector

    SUT.added!(self::TestCollector,item::TestCollected) = (self.addedCallNum += 1; push!(self.addedItems,item))
    SUT.sync!(self::TestCollector,item::TestCollected) = (self.syncedCallNum+=1; push!(self.syncedItems,item))
    SUT.addedAll!(self::TestCollector) = self.addedAllCallNum += 1
    SUT.syncAll!(self::TestCollector) = self.syncedAllCallNum += 1

    function clearState(self::TestCollector)
        self.addedCallNum = 0
        self.addedAllCallNum = 0
        empty!(self.addedItems)

        self.syncedCallNum = 0
        self.syncedAllCallNum = 0
        empty!(self.syncedItems)
    end

    frameTests = [
        ("Single 1 Sync",1,[
            [1]
        ]),
        ("Single 5 Sync",1,[
            [1],
            [1],
            [1],
            [1],
            [1]
        ]),
        ("Different 2 Syncs",2,[
            [1],
            [2],
            [1]
        ]),
        ("Different 3 Syncs",3,[
            [1],
            [2],
            [3],
            [2],
            [1]
        ]),
        ("All 3 syncs",3,[
            [1,2,3],
            [1,2,3],
            [1,2,3]
        ]),
        ("Some 3 syncs",3,[
            [1,2],
            [1,3],
            [2,3],
            [1],
            [2],
            [3]
        ]),
        ("Duplicated 3 syncs",3,[
            [3,3,3],
            [2,2,2],
            [1,1,1],
            [1,1,3,2,1,3,2]
        ]),
    ]

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

        @test collector.addedCallNum == 0
        @test collector.addedAllCallNum == 0
        @test collector.syncedCallNum == 0
        @test collector.syncedAllCallNum == 0
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

        @test collector.syncedCallNum == 0
        @test collector.syncedAllCallNum == 0
        @test isempty(collector.syncedItems)
        
        @test collector.addedCallNum == itemNum
        @test collector.addedAllCallNum == 1
        @test length(collector.addedItems) == itemNum

        for i in 1:itemNum
            @test collector.addedItems[i] === items[i]
        end
    end

    @testset "Sync are correct after update! in $(frameTest[1])" for frameTest in frameTests
        name,itemNum,frames = frameTest
        collector = TestCollector()
        items = []
        
        for i in 1:itemNum
            item = TestCollected()
            push!(items,item)
            SUT.add!!(collector,item)
        end
        
        SUT.update!!(collector)
        clearState(collector)

        for frame in frames
            itemsThatHaveToBeSynced = Set()
            
            for itemNum in frame
                SUT.flag4Sync!!(items[itemNum])
                push!(itemsThatHaveToBeSynced,itemNum)    
            end
            
            SUT.update!!(collector)
            
            @test collector.addedCallNum == 0
            @test collector.addedAllCallNum == 0
            @test isempty(collector.addedItems)

            @test collector.syncedAllCallNum == 1
            @test length(itemsThatHaveToBeSynced) == collector.syncedCallNum
            @test length(itemsThatHaveToBeSynced) == length(collector.syncedItems)

            for itemNum in itemsThatHaveToBeSynced
                @test count( item-> item===items[itemNum],collector.syncedItems) == 1 
            end

            clearState(collector)
        end
    end
end
