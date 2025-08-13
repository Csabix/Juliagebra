
@testset verbose=true "Collector and Collected Tests" begin
    import Juliagebra as SUT

    mutable struct TestCollected <: SUT.CollectedDNA
        _collected::SUT.Collected

        function TestCollected()
            collected = SUT.Collected()
            new(collected)
        end
    end

    mutable struct TestCollector{T} <: SUT.CollectorDNA{T}
        _collector::SUT.Collector{T}
        
        addedCallNum::Int
        addedAllCallNum::Int
        addedItems::Vector{T}
        
        syncedCallNum::Int
        syncedAllCallNum::Int
        syncedItems::Vector{T}
        
        function TestCollector{T}() where T
            collector = SUT.Collector{T}()
            new(collector,
                0,0,Vector{T}(),
                0,0,Vector{T}()
                )
        end
    end

    mutable struct TestCollectedCollector{T} <: SUT.CollectedCollectorDNA{T}
        _collectedCollector::SUT.CollectedCollector{T}

        addedCallNum::Int
        addedAllCallNum::Int
        addedItems::Vector{T}
        
        syncedCallNum::Int
        syncedAllCallNum::Int
        syncedItems::Vector{T}
        
        function TestCollectedCollector{T}() where T
            collector = SUT.CollectedCollector{T}()
            new(collector,
                0,0,Vector{T}(),
                0,0,Vector{T}()
                )
        end
    end

    SUT._Collected_(self::TestCollected)::SUT.Collected = return self._collected
    function SUT._Collector_(self::TestCollector{T})::SUT.Collector{T} where {T}
        return self._collector
    end

    function SUT._CollectedCollector_(self::TestCollectedCollector{T})::SUT.CollectedCollector{T} where {T} 
        return self._collectedCollector
    end
    
    SUT.added!(self::TestCollector{T},item::T) where T = _added!(self,item)
    SUT.added!(self::TestCollectedCollector{T},item::T) where T = _added!(self,item)
    _added!(self,item) = (self.addedCallNum += 1; push!(self.addedItems,item))

    SUT.sync!(self::TestCollector{T},item::T) where T = _sync!(self,item)
    SUT.sync!(self::TestCollectedCollector{T},item::T) where T = _sync!(self,item)
    _sync!(self,item) = (self.syncedCallNum+=1; push!(self.syncedItems,item))
    
    SUT.addedAll!(self::TestCollector) = _addedAll!(self)
    SUT.addedAll!(self::TestCollectedCollector) = _addedAll!(self)
    _addedAll!(self) = self.addedAllCallNum += 1
    
    SUT.syncAll!(self::TestCollector) = _syncAll!(self)
    SUT.syncAll!(self::TestCollectedCollector) = _syncAll!(self)
    _syncAll!(self) = self.syncedAllCallNum += 1

    clearState(self::TestCollector) = _clearState(self)
    clearState(self::TestCollectedCollector) = _clearState(self)
    function _clearState(self)
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

    function test_add!!(CollectorT::DataType,CollectedT::DataType)
        collector = CollectorT()
        collected = CollectedT()

        @test SUT.hasCollector(collected) == false
        SUT.add!!(collector,collected)
        @test SUT.hasCollector(collected) == true
    end

    function test_emptyCollector(CollectorT::DataType)
        collector = CollectorT()
        
        SUT.update!!(collector)

        @test collector.addedCallNum == 0
        @test collector.addedAllCallNum == 0
        @test collector.syncedCallNum == 0
        @test collector.syncedAllCallNum == 0
        @test isempty(collector.addedItems)
        @test isempty(collector.syncedItems)
    end

    function test_added!(CollectorT::DataType,CollectedT::DataType,itemNum::Int)
        collector = CollectorT()
        items = []

        for i in 1:itemNum
            push!(items,CollectedT())
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

    function test_sync!(CollectorT::DataType,CollectedT::DataType,frameTest)
        name,itemNum,frames = frameTest
        collector = CollectorT()
        items = []
        
        for i in 1:itemNum
            item = CollectedT()
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

    @testset "Collector with Collected tests" begin
        
        @testset "Collected has Collector after add!!" begin
            test_add!!(TestCollector{TestCollected},TestCollected)
        end
        
        @testset "Empty Collector is empty after update!" begin
            test_emptyCollector(TestCollector{TestCollected})
        end

        @testset "Collector collects added! calls correctly for $(itemNum) additions" for itemNum in [1,10]
            test_added!(TestCollector{TestCollected},TestCollected,itemNum)
        end

        @testset "Collector sync! calls are correct after update! for \"$(frameTest[1])\"" for frameTest in frameTests
            test_sync!(TestCollector{TestCollected},TestCollected,frameTest)
        end
    end

    @testset "CollectedCollector with Collected tests" begin
        
        CollectorT = TestCollectedCollector{TestCollected}
        CollectedT = TestCollected

        @testset "CollectedCollector has Collected after add!!" begin
            test_add!!(CollectorT,CollectedT)
        end
        
        @testset "Empty CollectedCollector is empty after update!" begin
            test_emptyCollector(CollectorT)
        end

        @testset "CollectedCollector collects added! calls correctly for $(itemNum) additions" for itemNum in [1,10]
            test_added!(CollectorT,CollectedT,itemNum)
        end

        @testset "CollectedCollector sync! calls are correct after update! for \"$(frameTest[1])\"" for frameTest in frameTests
            test_sync!(CollectorT,CollectedT,frameTest)
        end
    end

    @testset "Collector with CollectedCollector tests" begin
        
        CollectorT = TestCollector{TestCollectedCollector{TestCollected}}
        CollectedT = TestCollectedCollector{TestCollected}

        @testset "Collected has CollectedCollector after add!!" begin
            test_add!!(CollectorT,CollectedT)
        end
        
        @testset "Empty Collector is empty after update!" begin
            test_emptyCollector(CollectorT)
        end

        @testset "Collector collects added! calls correctly for $(itemNum) additions" for itemNum in [1,10]
            test_added!(CollectorT,CollectedT,itemNum)
        end

        @testset "Collector sync! calls are correct after update! for \"$(frameTest[1])\"" for frameTest in frameTests
            test_sync!(CollectorT,CollectedT,frameTest)
        end
    end

    @testset "CollectedCollector with CollectedCollector tests" begin
        
        CollectorT = TestCollectedCollector{TestCollectedCollector{TestCollected}}
        CollectedT = TestCollectedCollector{TestCollected}
    
        @testset "CollectedCollector has CollectedCollector after add!!" begin
            test_add!!(CollectorT,CollectedT)
        end
        
        @testset "Empty CollectedCollector is empty after update!" begin
            test_emptyCollector(CollectorT)
        end
    
        @testset "CollectedCollector collects added! calls correctly for $(itemNum) additions" for itemNum in [1,10]
            test_added!(CollectorT,CollectedT,itemNum)
        end
    
        @testset "CollectedCollector sync! calls are correct after update! for \"$(frameTest[1])\"" for frameTest in frameTests
            test_sync!(CollectorT,CollectedT,frameTest)
        end
    end

end
