
@testset verbose=true "DependentGraph and Dependent Tests" begin
    import Juliagebra as SUT

    mutable struct TestDependent <: SUT.DependentDNA
        _dependent::SUT.Dependent
        _onGraphEvalCalled::Int

        function TestDependent(callback::Function,graphParents::Vector{SUT.DependentDNA})
            new(SUT.Dependent(callback,graphParents),0)
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
        _onGraphEvalCalled::Int
    end

    SUT._Observed_(self::TestObserved)::SUT.Observed = return self._observed
    
    mutable struct TestObserver <: SUT.ObserverDNA{TestObserved}
        _observer::SUT.Observer{TestObserved}
        
        function TestObserver()
            new(SUT.Observer{TestObserved}())
        end
    end
    
    SUT._Observer_(self::TestObserver)::SUT.Observer = return self._observer
    SUT.added!(collector::TestObserver,collected::TestObserved) = nothing
    SUT.addedAll!(self::TestObserver) = nothing
    SUT.sync!(collector::TestObserver,collected::TestObserved) = nothing
    SUT.syncAll!(self::TestObserver) = nothing

    NULL_OBSERVER = TestObserver()

    TestObserved() = TestObserved(() -> (), Vector{SUT.DependentDNA}())
    function TestObserved(callback::Function,graphParents::Vector{SUT.DependentDNA})
        self = TestObserved(SUT.Observed(callback,graphParents),0)
        SUT.add!!(NULL_OBSERVER,self)

        return self
    end

    SUT.onGraphEval(self::TestDependent) = _onGraphEval(self)
    SUT.onGraphEval(self::TestObserved) = _onGraphEval(self)
    _onGraphEval(self) = self._onGraphEvalCalled += 1
    
    clearState(self::TestDependent) = _clearState(self)
    clearState(self::TestObserved) = _clearState(self)
    _clearState(self) = self._onGraphEvalCalled = 0

    function test_add!!(graph,asset)
        assetParents = SUT._Dependent_(asset)._graphParents

        SUT.add!!(graph,asset)

        @test SUT.fetch(graph,SUT._Dependent_(asset)._graphID) === asset

        parentsToCheck = assetParents

        while !isempty(parentsToCheck)
            newParentsToCheck = Set()
            for parent in parentsToCheck
                @test count(item -> item===asset,SUT._Dependent_(parent)._graphChain) == 1
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
                    @test dependents[childID]._onGraphEvalCalled == 1
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

    @testset verbose=true "DependentGraph - Dependent children test" begin 
        GraphT = TestDependentGraph
        DependentT = TestDependent
        
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
    end

    @testset verbose = true "DependentGraph - Observer - Observed children tests" begin
        GraphT = TestDependentGraph
        DependentT = TestObserved
        
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
    end
end