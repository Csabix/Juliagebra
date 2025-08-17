
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
    SUT.onGraphEval(self::TestDependent) = self._onGraphEvalCalled += 1
    clearState(self::TestDependent) = self._onGraphEvalCalled = 0

    mutable struct TestDependentGraph <: SUT.DependentGraphDNA
        _dependentGraph::SUT.DependentGraph

        function TestDependentGraph()
            new(SUT.DependentGraph())
        end
    end

    SUT._DependentGraph_(self::TestDependentGraph)::SUT.DependentGraph = return self._dependentGraph
    

    function test_add!!(graph::TestDependentGraph,asset::TestDependent)
        assetParents = asset._dependent._graphParents

        SUT.add!!(graph,asset)

        @test SUT.fetch(graph,asset._dependent._graphID) === asset

        parentsToCheck = assetParents

        while !isempty(parentsToCheck)
            newParentsToCheck = Set()
            for parent in parentsToCheck
                @test count(item -> item===asset,parent._dependent._graphChain) == 1
                for item in parent._dependent._graphParents
                    push!(newParentsToCheck,item)
                end
            end
            parentsToCheck = collect(newParentsToCheck)
        end

        return asset
    end

    @testset "DependentGraph add!! on empty graph with empty Dependent" begin
        graph = TestDependentGraph()
        dependent = TestDependent()
        
        test_add!!(graph,dependent)
    end

    @testset "DependentGraph add!! works on $(treeTestData[1] + 1) deep tree of Dependents with $(treeTestData[2]) number of childs" for treeTestData in [(1,2),(3,2),(5,3)]
        treeDepth,childNum = treeTestData
        
        graph = TestDependentGraph()
        dependent = TestDependent()

        test_add!!(graph,dependent)

        lastNodes = [dependent]

        for i in 1:treeDepth
            newLastNodes = []

            for lastNode in lastNodes
                for j in 1:childNum
                    graphParentsVec = Vector{SUT.DependentDNA}()
                    push!(graphParentsVec,lastNode)
                    asset = test_add!!(graph,TestDependent(() -> (),graphParentsVec))
                    push!(newLastNodes,asset)
                end
            end

            lastNodes = newLastNodes
        end
    end

    @testset "Dependent evalGraph evaluates only once" begin
        graphData = [
            (1)
            (1)
            (2,3)
            (4)
            (1,5)
            (2,4)
            (7)
            (2,4,5,8)
            ()
            (3)
            (10,11)
            (11)
            (11)
            (12)
        ]

        graphItemSize = length(graphData)+1
        #paths = falses(graphItemSize,graphItemSize)
        paths = [Vector{Int}() for i in 1:graphItemSize]


        graph = TestDependentGraph()
        dependent = TestDependent()

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
            
            asset = test_add!!(graph,TestDependent(() -> (),parentDependents))
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
end