
@testset verbose=true "DependentGraph and Dependent Tests" begin
    import Juliagebra as SUT
    using JSON

    mutable struct TestDependent <: SUT.DependentDNA
        _dependent::SUT.Dependent
        _onGraphEvalCalledNum::Int
        _onGraphEvalParentNums::Vector

        function TestDependent(callback::Function,graphParents::Vector{SUT.DependentDNA})
            new(SUT.Dependent(callback,graphParents),0,[])
        end
    end

    TestDependent() = TestDependent(() -> (), Vector{SUT.DependentDNA}())
    SUT._Dependent_(self::TestDependent)::SUT.Dependent = return self._dependent

    mutable struct TestDependentGraph <: SUT.DependentGraphDNA
        _dependentGraph::SUT.DependentGraph

        function TestDependentGraph()
            new(SUT.DependentGraph())
        end
    end

    SUT._DependentGraph_(self::TestDependentGraph)::SUT.DependentGraph = return self._dependentGraph
    
    mutable struct TestObserved <: SUT.ObservedDNA
        _observed::SUT.Observed
        _onGraphEvalCalledNum::Int
        _onGraphEvalParentNums::Vector
    end

    SUT._Observed_(self::TestObserved)::SUT.Observed = return self._observed
    
    mutable struct TestObserver <: SUT.ObserverDNA{TestObserved}
        _observer::SUT.Observer{TestObserved}
        _addedCalled::Int
        _syncCalled::Int
        _syncAllCalled::Int
        
        _addedItems::Vector
        _syncItems::Vector

        function TestObserver()
            new(SUT.Observer{TestObserved}(),
                0,0,0,[],[])
        end
    end
    
    SUT._Observer_(self::TestObserver)::SUT.Observer = return self._observer
    function SUT.added!(collector::TestObserver,collected::TestObserved) 
        collector._addedCalled += 1
        push!(collector._addedItems,collected)
    end
    SUT.addedAll!(self::TestObserver) = nothing
    function SUT.sync!(collector::TestObserver,collected::TestObserved) 
        collector._syncCalled += 1
        push!(collector._syncItems,collected)
    end
    function SUT.syncAll!(self::TestObserver)
        self._syncAllCalled += 1
    end

    NULL_OBSERVER = TestObserver()

    TestObserved() = TestObserved(() -> (), Vector{SUT.DependentDNA}())
    TestObserved(callback::Function,graphParents::Vector{SUT.DependentDNA}) = TestObserved(callback,graphParents,NULL_OBSERVER)
    function TestObserved(callback::Function,graphParents::Vector{SUT.DependentDNA},observer)
        self = TestObserved(SUT.Observed(callback,graphParents),0,[])
        SUT.add!!(observer,self)
        return self
    end

    SUT.onGraphEval(self::TestDependent) = _onGraphEval(self)
    SUT.onGraphEval(self::TestObserved) = _onGraphEval(self)
    function _onGraphEval(self) 
        self._onGraphEvalCalledNum += 1
        parents = SUT.getGraphParents(self)
        self._onGraphEvalParentNums = [(SUT.getGraphID(parent),parent._onGraphEvalCalledNum) for parent in parents]
    end 

    clearState(self::TestDependent) = _clearState(self)
    clearState(self::TestObserved) = _clearState(self)
    function _clearState(self::SUT.DependentDNA) 
        self._onGraphEvalCalledNum = 0
        self._onGraphEvalParentNums = []
    end

    clearState(self::TestObserver) = _clearState(self)
    function _clearState(self::SUT.ObserverDNA)
        self._addedCalled = 0
        self._syncCalled = 0
        self._syncAllCalled = 0

        self._addedItems = []
        self._syncItems = []
    end

    function test_add!!(graph,asset,observer)
        SUT.add!!(observer,asset)
        return test_add!!(graph,asset)
    end

    function test_add!!(graph,asset)
        assetParents = SUT._Dependent_(asset)._graphParents

        SUT.add!!(graph,asset)

        @test SUT.fetch(graph,SUT._Dependent_(asset)._graphID) === asset

        parentsToCheck = assetParents

        while !isempty(parentsToCheck)
            newParentsToCheck = Set()
            for parent in parentsToCheck
                @test count(item -> item===asset,SUT.dependentsOf(SUT.getChain(parent))) == 1
                for item in SUT._Dependent_(parent)._graphParents
                    push!(newParentsToCheck,item)
                end
            end
            parentsToCheck = collect(newParentsToCheck)
        end

        return asset
    end

    function test_empty_add!!(GraphT::DataType,DependentT::DataType)
        graph = GraphT()
        dependent = DependentT()
        
        test_add!!(graph,dependent)
    end

    function test_tree_add!!(GraphT::DataType,DependentT::DataType,treeTestData)
        treeDepth,childNum = treeTestData
        
        graph = GraphT()
        dependent = DependentT()

        test_add!!(graph,dependent)

        lastNodes = [dependent]

        for i in 1:treeDepth
            newLastNodes = []

            for lastNode in lastNodes
                for j in 1:childNum
                    graphParentsVec = Vector{SUT.DependentDNA}()
                    push!(graphParentsVec,lastNode)
                    asset = test_add!!(graph,DependentT(() -> (),graphParentsVec))
                    push!(newLastNodes,asset)
                end
            end

            lastNodes = newLastNodes
        end
    end

    testGraphs = [
        ("Somewhat complex graph",[
            (1),
            (1),
            (2,3),
            (4),
            (1,5),
            (2,4),
            (7),
            (2,4,5,8),
            (),
            (3),
            (10,11),
            (11),
            (11),
            (12)
        ])
    ]

    function test_evalGraph(GraphT::DataType,DependentT::DataType,graphData)
        
        graphItemSize = length(graphData)+1
        #paths = falses(graphItemSize,graphItemSize)
        paths = [Vector{Int}() for i in 1:graphItemSize]


        graph = GraphT()
        dependent = DependentT()

        test_add!!(graph,dependent)

        dependents = [dependent]

        #println("Graph Data:")
        for i in eachindex(graphData)
            nodeData = graphData[i]
            parentDependents = Vector{SUT.DependentDNA}()
            nodeID = i+1
            for parentID in nodeData
                push!(parentDependents,dependents[parentID])
                push!(paths[parentID],nodeID)
                #println("\t$(parentID) -> $(nodeID)")
            end
            
            asset = test_add!!(graph,DependentT(() -> (),parentDependents))
            push!(dependents,asset)
        end
        
        for pathID in eachindex(paths)
            #println("Testing $(pathID):")    
            SUT.evalGraph(dependents[pathID])            
            childIDs = paths[pathID]

            while !isempty(childIDs)
                newChildIDs = Set()
                for childID in childIDs
                    #println("\t$(childID):")
                    @test dependents[childID]._onGraphEvalCalledNum == 1
                    for newChildID in paths[childID]
                        push!(newChildIDs,newChildID)
                        #println("\t\t$(childID) -> $(newChildID)")
                    end
                end
                childIDs = collect(newChildIDs)
            end
            
            for dependent in dependents
                clearState(dependent)
            end
        end
    end

    function init_jsonGraph(GraphT::DataType,DependentT::DataType,jsonGraph)
        
        graph = GraphT()
        dependents = []

        for nodeIndex in eachindex(jsonGraph["node_paths"])
            nodePaths = jsonGraph["node_paths"][nodeIndex]
            nodeParents = Vector{SUT.DependentDNA}([dependents[parentIndex] for parentIndex in nodePaths])
            
            dependent = test_add!!(graph,DependentT(() -> (),nodeParents))
            push!(dependents,dependent)
        end

        return (graph,dependents)
    end

    function clear_dependents(dependents)
        for dependent in dependents
            clearState(dependent)
        end
    end

    function clear_observers(observers)
        for observer in observers
            clearState(observer)
        end
    end

    function test_eval_totalCallCount(graph,dependents,jsonGraph)
        for testPath in jsonGraph["test_paths"]
            testPathEvalNodeIndex = parse(Int,testPath[1])
            testPathNodeIndexes = testPath[2]

            SUT.evalGraph(dependents[testPathEvalNodeIndex])

            totalDependentEvalCalled = 0
            for dependent in dependents
                totalDependentEvalCalled += dependent._onGraphEvalCalledNum
            end

            @test totalDependentEvalCalled == length(testPathNodeIndexes)

            clear_dependents(dependents)
        end
    end

    function test_eval_dependentsCalledOnly(graph,dependents,jsonGraph)
        for testPath in jsonGraph["test_paths"]
            testPathEvalNodeIndex = parse(Int,testPath[1])
            testPathNodeIndexes = testPath[2]

            SUT.evalGraph(dependents[testPathEvalNodeIndex])

            for depententIndex in eachindex(dependents)
                dependent = dependents[depententIndex]
                if depententIndex in testPathNodeIndexes
                    @test dependent._onGraphEvalCalledNum != 0
                else
                    @test dependent._onGraphEvalCalledNum == 0
                end
            end
            
            clear_dependents(dependents)
        end
    end

    function test_eval_orderOfDependentsCalled(graph,dependents,jsonGraph)
        for testPath in jsonGraph["test_paths"]
            testPathEvalNodeIndex = parse(Int,testPath[1])
            testPathNodeIndexes = testPath[2]

            SUT.evalGraph(dependents[testPathEvalNodeIndex])

            for depententIndex in eachindex(dependents)
                dependent = dependents[depententIndex]
                
                for parentData in dependent._onGraphEvalParentNums
                    parentIndex,parentNum = parentData
                    if parentIndex in testPathNodeIndexes 
                        @test parentNum != 0
                    else
                        @test parentNum == 0
                    end
                end
            end

            clear_dependents(dependents)
        end
    end

    function init_observed_jsonGraph(GraphT::DataType,ObservedT::DataType,ObserverT::DataType,jsonGraph,observerConfigName)
        graph = GraphT()
        observed = []
        observers = []

        for observerConfig in jsonGraph["observer_configs"][observerConfigName]
            push!(observers,ObserverT())
        end

        for nodeIndex in eachindex(jsonGraph["node_paths"])
            nodePaths = jsonGraph["node_paths"][nodeIndex]
            nodeParents = Vector{SUT.DependentDNA}([observed[parentIndex] for parentIndex in nodePaths])
            nodeObserver = nothing

            for observerConfigIndex in eachindex(jsonGraph["observer_configs"][observerConfigName])
                observerConfig = jsonGraph["observer_configs"][observerConfigName][observerConfigIndex]
                if nodeIndex in observerConfig
                    nodeObserver = observers[observerConfigIndex]
                    break
                end
            end

            if !isnothing(nodeObserver)
                dependent = test_add!!(graph,ObservedT(() -> (),nodeParents),nodeObserver)
            else
                dependent = test_add!!(graph,ObservedT(() -> (),nodeParents))
            end
            
            push!(observed,dependent)
        end

        return (graph,observed,observers)
    end

    function test_added_totalCallCount(graph,observed,observers,jsonGraph,observerConfigName)
        observerConfigs = jsonGraph["observer_configs"][observerConfigName]

        for observerConfigIndex in eachindex(observerConfigs)
            observerConfig = observerConfigs[observerConfigIndex]
            @test observers[observerConfigIndex]._addedCalled == length(observerConfig)
        end
    end

    function test_added_observedCalledOnly(graph,observed,observers,jsonGraph,observerConfigName)
        observerConfigs = jsonGraph["observer_configs"][observerConfigName]

        for observerConfigIndex in eachindex(observerConfigs)
            observerConfig = observerConfigs[observerConfigIndex]
            
            @test length(observers[observerConfigIndex]._addedItems) == length(observerConfig)

            for addedItemIndex in observerConfig
                @test observed[addedItemIndex] in observers[observerConfigIndex]._addedItems
            end
        end
    end

    function test_sync_totalCallCount(graph,observed,observers,jsonGraph,observerConfigName)
        observerConfigs = jsonGraph["observer_configs"][observerConfigName]
        
        for testPath in jsonGraph["test_paths"]
            testPathEvalNodeIndex = parse(Int,testPath[1])
            testPathNodeIndexes = testPath[2]

            SUT.evalGraph(observed[testPathEvalNodeIndex])

            for observerConfigIndex in eachindex(observerConfigs)
                observerConfig = observerConfigs[observerConfigIndex]
                
                observedInPathCount = 0
                for observedIndex in observerConfig
                    if observedIndex in testPathNodeIndexes
                        observedInPathCount += 1
                    end
                end
                
                @test observers[observerConfigIndex]._syncCalled == observedInPathCount

            end

            clear_observers(observers)
            clear_dependents(observed)
        end
    end

    function test_sync_observedCalledOnly(graph,observed,observers,jsonGraph,observerConfigName)
        observerConfigs = jsonGraph["observer_configs"][observerConfigName]
        
        for testPath in jsonGraph["test_paths"]
            testPathEvalNodeIndex = parse(Int,testPath[1])
            testPathNodeIndexes = testPath[2]

            SUT.evalGraph(observed[testPathEvalNodeIndex])

            for observerConfigIndex in eachindex(observerConfigs)
                observerConfig = observerConfigs[observerConfigIndex]
                
                observedInPath = []
                for observedIndex in observerConfig
                    if observedIndex in testPathNodeIndexes
                        push!(observedInPath,observed[observedIndex])
                    end
                end
                
                @test length(observers[observerConfigIndex]._syncItems) == length(observedInPath)

                for observed in observedInPath
                    @test observed in observers[observerConfigIndex]._syncItems
                end
            end

            clear_observers(observers)
            clear_dependents(observed)
        end
    end

    function test_syncAll_totalCallCount(graph,observed,observers,jsonGraph,observerConfigName)
        observerConfigs = jsonGraph["observer_configs"][observerConfigName]
        
        for testPath in jsonGraph["test_paths"]
            testPathEvalNodeIndex = parse(Int,testPath[1])
            testPathNodeIndexes = testPath[2]

            SUT.evalGraph(observed[testPathEvalNodeIndex])

            for observerConfigIndex in eachindex(observerConfigs)
                observerConfig = observerConfigs[observerConfigIndex]
                
                observerInPath = false
                for observedIndex in observerConfig
                    if observedIndex in testPathNodeIndexes
                        observerInPath = true
                        break
                    end
                end

                if observerInPath
                    @test observers[observerConfigIndex]._syncAllCalled == 1
                else
                    @test observers[observerConfigIndex]._syncAllCalled == 0
                end
            end

            clear_observers(observers)
            clear_dependents(observed)
        end
    end

    @testset verbose=true "DependentGraph - Dependent children test" begin 
        GraphT = TestDependentGraph
        DependentT = TestDependent
        jsonGraphData = JSON.parsefile("graph_data.json")

        @testset "add!! on empty graph with empty dependent" begin
            test_empty_add!!(GraphT,DependentT)
        end

        @testset "add!! works on $(treeTestData[1] + 1) deep tree of dependents with $(treeTestData[2]) number of childs" for treeTestData in [(1,2),(3,2),(5,3)]
            test_tree_add!!(GraphT,DependentT,treeTestData)
        end

        @testset "evalGraph evaluates only once on graph: \"$(testGraph[1])\"" for testGraph in testGraphs
            name,graphData = testGraph
            test_evalGraph(GraphT,DependentT,graphData) 
        end

        @testset "evalGraph total evaluation count is correct on jsonGraph: \"$(jsonGraph["name"])\"" for jsonGraph in jsonGraphData["graphs"]
            graph,dependents = init_jsonGraph(GraphT,DependentT,jsonGraph)
            test_eval_totalCallCount(graph,dependents,jsonGraph)
        end

        @testset "evalGraph evaluates only on dependents in path on jsonGraph: \"$(jsonGraph["name"])\"" for jsonGraph in jsonGraphData["graphs"]
            graph,dependents = init_jsonGraph(GraphT,DependentT,jsonGraph)
            test_eval_dependentsCalledOnly(graph,dependents,jsonGraph)
        end

        @testset "evalGraph evaluates in correct order on jsonGraph: \"$(jsonGraph["name"])\"" for jsonGraph in jsonGraphData["graphs"]
            graph,dependents = init_jsonGraph(GraphT,DependentT,jsonGraph)
            test_eval_orderOfDependentsCalled(graph,dependents,jsonGraph)
        end
    end

    @testset verbose = true "DependentGraph - Observed children tests" begin
        GraphT = TestDependentGraph
        ObservedT = TestObserved
        ObserverT = TestObserver
        jsonGraphData = JSON.parsefile("graph_data.json")

        @testset "add!! on empty graph with empty dependent" begin
            test_empty_add!!(GraphT,ObservedT)
        end

        @testset "add!! works on $(treeTestData[1] + 1) deep tree of dependents with $(treeTestData[2]) number of childs" for treeTestData in [(1,2),(3,2),(5,3)]
            test_tree_add!!(GraphT,ObservedT,treeTestData)
        end

        @testset "evalGraph evaluates only once on graph: \"$(testGraph[1])\"" for testGraph in testGraphs
            name,graphData = testGraph
            test_evalGraph(GraphT,ObservedT,graphData) 
        end

        @testset verbose = true "Graph with Observers tests on jsonGraph: \"$(jsonGraph["name"])\"" for jsonGraph in jsonGraphData["graphs"]
            
            @testset "evalGraph evaluates only once on observerSetup: \"$(observerConfig[1])\"" for observerConfig in jsonGraph["observer_configs"]
                observerConfigName,observerConfigData = observerConfig
                graph,observed,observers = init_observed_jsonGraph(GraphT,ObservedT,ObserverT,jsonGraph,observerConfigName)
                test_eval_totalCallCount(graph,observed,jsonGraph)
            end
            
            @testset "evalGraph evaluates only on dependents in path on observerSetup: \"$(observerConfig[1])\"" for observerConfig in jsonGraph["observer_configs"] 
                observerConfigName,observerConfigData = observerConfig
                graph,observed,observers = init_observed_jsonGraph(GraphT,ObservedT,ObserverT,jsonGraph,observerConfigName)
                test_eval_dependentsCalledOnly(graph,observed,jsonGraph)
            end

            @testset "evalGraph evaluates in correct order on observerSetup: \"$(observerConfig[1])\"" for observerConfig in jsonGraph["observer_configs"] 
                observerConfigName,observerConfigData = observerConfig
                graph,observed,observers = init_observed_jsonGraph(GraphT,ObservedT,ObserverT,jsonGraph,observerConfigName)
                test_eval_orderOfDependentsCalled(graph,observed,jsonGraph)
            end

            @testset "added call count is correct on observerSetup: \"$(observerConfig[1])\"" for observerConfig in jsonGraph["observer_configs"] 
                observerConfigName,observerConfigData = observerConfig
                graph,observed,observers = init_observed_jsonGraph(GraphT,ObservedT,ObserverT,jsonGraph,observerConfigName)
                test_added_totalCallCount(graph,observed,observers,jsonGraph,observerConfigName)
            end

            @testset "added calls only on observed items on observerSetup: \"$(observerConfig[1])\"" for observerConfig in jsonGraph["observer_configs"]
                observerConfigName,observerConfigData = observerConfig
                graph,observed,observers = init_observed_jsonGraph(GraphT,ObservedT,ObserverT,jsonGraph,observerConfigName)
                test_added_observedCalledOnly(graph,observed,observers,jsonGraph,observerConfigName)
            end

            @testset "sync call count is correct on observerSetup: \"$(observerConfig[1])\"" for observerConfig in jsonGraph["observer_configs"]
                observerConfigName,observerConfigData = observerConfig
                graph,observed,observers = init_observed_jsonGraph(GraphT,ObservedT,ObserverT,jsonGraph,observerConfigName)
                test_sync_totalCallCount(graph,observed,observers,jsonGraph,observerConfigName)
            end

            @testset "sync calls only on correct observed in observerSetup: \"$(observerConfig[1])\"" for observerConfig in jsonGraph["observer_configs"]
                observerConfigName,observerConfigData = observerConfig
                graph,observed,observers = init_observed_jsonGraph(GraphT,ObservedT,ObserverT,jsonGraph,observerConfigName)
                test_sync_observedCalledOnly(graph,observed,observers,jsonGraph,observerConfigName)
            end

            @testset "syncAll call count is correct on observerSetup: \"$(observerConfig[1])\"" for observerConfig in jsonGraph["observer_configs"]
                observerConfigName,observerConfigData = observerConfig
                graph,observed,observers = init_observed_jsonGraph(GraphT,ObservedT,ObserverT,jsonGraph,observerConfigName)
                test_syncAll_totalCallCount(graph,observed,observers,jsonGraph,observerConfigName)
            end
        end
    end
end