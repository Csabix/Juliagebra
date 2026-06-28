
@testset verbose=true "Model Tests" begin
    import Juliagebra as SUT

    mutable struct MockDependent <: SUT.DependentDNA
        _dependent::SUT.Dependent
        _tag::Int

        function MockDependent(callback::Function, dependents::Vector{<:SUT.DependentDNA}, tag::Int)
            dependent = SUT.Dependent(callback, dependents)
            new(dependent, tag)
        end

        function MockDependent(dependents::Vector{<:SUT.DependentDNA}, tag::Int)
            return MockDependent(() -> (return nothing), dependents, tag)
        end

        function MockDependent(tag::Int)
            return MockDependent(Vector{SUT.DependentDNA}(), tag)
        end
    end

    SUT._Dependent_(self::MockDependent)::SUT.Dependent = return self._dependent
    SUT.onNodeEval(self::MockDependent) = return nothing

    function _buildall(model::SUT.Model)
        for i in 1:4
            node = take!(model._builder._in)
            SUT._build(model, node)
        end
    end

    @testset verbose=true "Construction Tests" begin
        model = SUT.Model()        
        
        node1 = MockDependent(1)
        node2 = MockDependent([node1],2)
        node3 = MockDependent([node1],3)
        node4 = MockDependent([node2, node3], 4)

        SUT.build!(model, node1)
        SUT.build!(model, node2)
        SUT.build!(model, node3)
        SUT.build!(model, node4)

        _buildall(model)

        @test Set(SUT.getSchedule(node1)._vec) == Set([node2, node3, node4])
        @test Set(SUT.getSchedule(node2)._vec) == Set([node4])
        @test Set(SUT.getSchedule(node3)._vec) == Set([node4])
        @test isempty(SUT.getSchedule(node4))
    end

    @testset verbose=true "Evaluation Tests" begin
        
    end
end