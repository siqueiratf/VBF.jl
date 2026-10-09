@testitem "automorphism_provenance" begin
    using VBF, Test

    @testset "completed native results retain a detached source graph" begin
        for algorithm in (:paper, :optimized), relation in (:ccz, :ea)
            F = gold_apn(3, 1)
            H = partition_refinement_automorphisms(F; algorithm, relation)
            expected = copy(FunctionGraph(F).packed)
            @test H.complete
            @test H.graph_points == expected
            @test H.graph_points !== F.lut
            F.lut[1] ⊻= one(eltype(F.lut))
            @test FunctionGraph(F).packed != expected
            @test H.graph_points == expected
        end
        rectangular = VBFTable{2,1}([0,0,0,1])
        H = partition_refinement_automorphisms(rectangular)
        @test H.complete
        @test H isa AutomorphismGroupResult{3}
        @test H.graph_points == FunctionGraph(rectangular).packed
    end

    @testset "legacy constructors remain unbound subgroup results" begin
        generators = F2AffineMap{4,UInt32}[]
        for constructor in (AutomorphismGroupResult{4}, AutomorphismGroupResult)
            H = constructor(:ccz, generators, true, :none,
                BigInt(1), BigInt(1), BigInt(1), 0, 0.0)
            @test H isa AutomorphismGroupResult{4}
            @test H.graph_points === nothing
            @test H.complete
            @test H.generators === generators
            @test H.order == 1
        end
    end

    @testset "early budget stops do not require source materialization" begin
        F = gold_apn(3, 1)
        for kwargs in ((max_nodes = 0,), (timeout_seconds = 0,),
                       (max_memory_bytes = 0,))
            H = partition_refinement_automorphisms(F; kwargs...)
            @test !H.complete
            @test H.graph_points === nothing
            @test isempty(H.generators)
            @test H.nodes_visited == 0
        end
        partial = partition_refinement_automorphisms(F; max_nodes = 1)
        @test !partial.complete
        @test partial.graph_points === nothing
    end
end
