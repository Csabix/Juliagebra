
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

    function _buildall(model::SUT.Model, amount::Int)
        for i in 1:amount
            node = take!(model._builder._in)
            SUT._build(model, node)
        end
    end

    @testset verbose=true "Construction Tests" begin
        @testset "Diamond" begin
            model = SUT.Model()        
        
            node1 = MockDependent()
            node2 = MockDependent([node1])
            node3 = MockDependent([node1])
            node4 = MockDependent([node2, node3])

            SUT.build!(model, node1)
            SUT.build!(model, node2)
            SUT.build!(model, node3)
            SUT.build!(model, node4)

            _buildall(model,4)

            @test SUT.get_set(SUT.getSchedule(node1)) == Set([2, 3, 4])
            @test SUT.get_set(SUT.getSchedule(node2)) == Set([4])
            @test SUT.get_set(SUT.getSchedule(node3)) == Set([4])
            @test isempty(SUT.getSchedule(node4))
        end

        @testset "DAG" begin
            model = SUT.Model()        
        
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

            _buildall(model,7)

            @test SUT.get_set(SUT.getSchedule(node1)) == Set([2,3,4,5,6,7])
            @test SUT.get_set(SUT.getSchedule(node2)) == Set([4,5])
            @test SUT.get_set(SUT.getSchedule(node3)) == Set([6,7])
            @test isempty(SUT.getSchedule(node4))
            @test isempty(SUT.getSchedule(node5))
            @test isempty(SUT.getSchedule(node6))
            @test isempty(SUT.getSchedule(node7))
        end

        @testset "Sink" begin
            model = SUT.Model()        
        
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

            _buildall(model,6)

            @test SUT.get_set(SUT.getSchedule(node1)) == Set([4,6])
            @test SUT.get_set(SUT.getSchedule(node2)) == Set([4,5,6])
            @test SUT.get_set(SUT.getSchedule(node3)) == Set([5,6])
            @test SUT.get_set(SUT.getSchedule(node4)) == Set([6])
            @test SUT.get_set(SUT.getSchedule(node5)) == Set([6])
            @test isempty(SUT.getSchedule(node6))
        end
    end

    @testset verbose=true "Evaluation Tests" begin
        
    end
end