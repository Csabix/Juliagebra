
@testset verbose=true "Model Tests" begin
    import Juliagebra as SUT

    mutable struct MockDependent <: SUT.DependentDNA
        _dependent::SUT.Dependent

        function MockDependent(callback::Function, dependents::Vector{<:SUT.DependentDNA})
            dependent = SUT.Dependent(callback, dependents)
            new(dependent)
        end

        function MockDependent(dependents::Vector{<:SUT.DependentDNA})
            return MockDependent(() -> (return nothing), dependents)
        end

        function MockDependent()
            return MockDependent(Vector{SUT.DependentDNA}())
        end
    end

    SUT._Dependent_(self::MockDependent)::SUT.Dependent = return self._dependent
    SUT.onNodeEval(::MockDependent) = return nothing

    function construct_avail!(model)
        SUT.process_avail!(SUT.getBuilder(model), model)
        SUT.process_avail!(SUT.getAdder(model); send_log=false)
    end

    function Diamond(model)
        node1 = MockDependent()
        node2 = MockDependent([node1])
        node3 = MockDependent([node1])
        node4 = MockDependent([node2, node3])

        SUT.build!(model, node1)
        SUT.build!(model, node2)
        SUT.build!(model, node3)
        SUT.build!(model, node4)

        construct_avail!(model)

        return [node1,node2,node3,node4]
    end

    function DAG(model)
        node1 = MockDependent()
        node2 = MockDependent([node1])
        node3 = MockDependent([node1])
        node4 = MockDependent([node2])
        node5 = MockDependent([node2])
        node6 = MockDependent([node3])
        node7 = MockDependent([node3])
            
        SUT.build!(model, node1)
        SUT.build!(model, node2)
        SUT.build!(model, node3)
        SUT.build!(model, node4)
        SUT.build!(model, node5)
        SUT.build!(model, node6)
        SUT.build!(model, node7)

        construct_avail!(model)

        return [node1, node2, node3, node4, node5, node6, node7]
    end

    function Sink(model)
        node1 = MockDependent()
        node2 = MockDependent()
        node3 = MockDependent()
        node4 = MockDependent([node1,node2])
        node5 = MockDependent([node2,node3])
        node6 = MockDependent([node4,node5])
            
        SUT.build!(model, node1)
        SUT.build!(model, node2)
        SUT.build!(model, node3)
        SUT.build!(model, node4)
        SUT.build!(model, node5)
        SUT.build!(model, node6)

        construct_avail!(model)

        return [node1, node2, node3, node4, node5, node6]
    end

    @testset verbose=true "Construction Tests" begin
        @testset "Diamond" begin
            model = SUT.Model()        
            nodes = Diamond(model)

            @test SUT.get_set(SUT.get_subgraph(nodes[1])) == Set([2, 3, 4])
            @test SUT.get_set(SUT.get_subgraph(nodes[2])) == Set([4])
            @test SUT.get_set(SUT.get_subgraph(nodes[3])) == Set([4])
            @test isempty(SUT.get_subgraph(nodes[4]))
        end

        @testset "DAG" begin
            model = SUT.Model()                
            nodes = DAG(model)

            @test SUT.get_set(SUT.get_subgraph(nodes[1])) == Set([2,3,4,5,6,7])
            @test SUT.get_set(SUT.get_subgraph(nodes[2])) == Set([4,5])
            @test SUT.get_set(SUT.get_subgraph(nodes[3])) == Set([6,7])
            @test isempty(SUT.get_subgraph(nodes[4]))
            @test isempty(SUT.get_subgraph(nodes[5]))
            @test isempty(SUT.get_subgraph(nodes[6]))
            @test isempty(SUT.get_subgraph(nodes[7]))
        end

        @testset "Sink" begin
            model = SUT.Model()        
            nodes = Sink(model)

            @test SUT.get_set(SUT.get_subgraph(nodes[1])) == Set([4,6])
            @test SUT.get_set(SUT.get_subgraph(nodes[2])) == Set([4,5,6])
            @test SUT.get_set(SUT.get_subgraph(nodes[3])) == Set([5,6])
            @test SUT.get_set(SUT.get_subgraph(nodes[4])) == Set([6])
            @test SUT.get_set(SUT.get_subgraph(nodes[5])) == Set([6])
            @test isempty(SUT.get_subgraph(nodes[6]))
        end
    end

    @testset verbose=true "Evaluation Tests" begin
        
    end
end