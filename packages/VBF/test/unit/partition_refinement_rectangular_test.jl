@testitem "partition_refinement_rectangular" begin
    using VBF, Test, Random

    @testset "rectangular truth tables and graph coordinates" begin
        F = VBFTable{2,1}([0,0,0,1])
        @test inputbits(F) == 2 && outputbits(F) == 1
        @test F(3) == F[3] == 1
        @test FunctionGraph(F).packed == UInt32[0,2,4,7]
        @test algebraic_degree(F) == 2 && mobius!(anf(F)) == F.lut
        @test copy(F) == F && copy(F).lut !== F.lut
        @test_throws ArgumentError VBFTable{2,1}([0,0,0,2])
        @test_throws ArgumentError VBFTable{2,1}([0,0,0,-1])
        @test_throws ArgumentError VBFTable{2,1}([0,0])
        @test_throws ArgumentError FunctionGraph(VBFTable{1,32}([0,1]))
    end

    @testset "all AGL(3,2) maps give independent rectangular group orders" begin
        for (n,m) in ((1,2),(2,1)), code in 0:((1 << (m*(1<<n)))-1)
            F = VBFTable{n,m}([(code >> (m*x)) & ((1<<m)-1) for x in 0:((1<<n)-1)])
            graph = FunctionGraph(F).packed
            expected = zeros(Int,2)
            for a in 1:7, b in 1:7, c in 1:7
                values = [(x&1!=0 ? a : 0) ⊻ (x&2!=0 ? b : 0) ⊻
                          (x&4!=0 ? c : 0) for x in 0:7]
                length(unique(values)) == 8 || continue
                ea = all(v -> v >> m == 0,(a,b,c)[1:m])
                for t in 0:7
                    all(p -> (values[Int(p)+1] ⊻ t) in graph,graph) || continue
                    expected[1] += 1
                    ea && (expected[2] += 1)
                end
            end
            for (j,relation) in enumerate((:ccz,:ea))
                H = partition_refinement_automorphisms(F;relation)
                @test H.complete && H.order == expected[j]
                @test H.order == H.graph_order * H.kernel_order
                @test all(A -> is_invertible(A) && ccz_equivalent_function(F,A)==F,H.generators)
            end
        end
    end

    @testset "unequal widths, affine translations and mixed square representations" begin
        rng = Xoshiro(94021)
        for (n,m) in ((2,3),(3,2),(4,1),(1,4))
            F = VBFTable{n,m}(rand(rng,0:((1<<m)-1),1<<n))
            G = VBFTable{n,m}([F(x ⊻ 1) ⊻ 1 for x in 0:((1<<n)-1)])
            for relation in (:ccz,:ea)
                r = partition_refinement_equivalence(F,G;relation)
                @test r isa Found
                @test ccz_equivalent_function(F,only(search_solutions(r))) == G
                H = partition_refinement_automorphisms(G;relation)
                @test H.complete
                @test partition_refinement_equivalence(F,G;relation,automorphisms=H) isa Found
            end
            @test are_ccz_equivalent(F,G;on_inconclusive=:throw)
            @test are_ea_equivalent(F,G;on_inconclusive=:throw)
            @test ccz_equivalent_function(F,ccz_equivalence_certificate(F,G))==G
            c = ea_equivalence_certificate(F,G)
            @test is_invertible(c.L1) && is_invertible(c.A2)
            @test all(c.L1(F(c.A2(x))) ⊻ c.A_drift(x)==G(x) for x in 0:(length(F)-1))
            @test ea_equivalence_certificate(F,G;max_nodes=0,on_inconclusive=:missing)===missing
        end
        F = SBox{2}([0,1,3,2])
        @test partition_refinement_equivalence(F,VBFTable{2,2}(F.lut)) isa Found
        @test partition_refinement_equivalence(VBFTable{2,1}([0,0,0,1]),VBFTable{1,2}([0,1])) isa Exhausted
    end
end
