@testitem "partition_refinement_api" begin
    using VBF, Test, Random

    rng = Xoshiro(940)
    @testset "existing EA triple includes input translation and affine drift" begin
        for n in 3:7, trial in 1:3
            F = random_function_sbox(rng, Val(n))
            inner = random_affine_permutation(rng, Val(n))
            outer = random_affine_permutation(rng, Val(n))
            drift = random_linear_function(rng, Val(n))
            G = SBox{n}([outer(F(inner(x))) ⊻ drift(x) for x in 0:((1 << n)-1)])
            for strategy in (:auto, :partition_refinement)
                @test are_ea_equivalent(F, G; strategy, on_inconclusive = :throw)
                @test are_ccz_equivalent(F, G; strategy, on_inconclusive = :throw)
                c = ea_equivalence_certificate(F, G; strategy)
                @test c !== nothing
                @test is_invertible(c.L1) && is_invertible(c.A2)
                @test algebraic_degree(c.A_drift) <= 1
                @test all(c.L1(F(c.A2(x))) ⊻ c.A_drift(x) == G(x) for x in 0:((1 << n)-1))
            end
        end
    end

    @testset "CCZ graph packing, swapping and nonquadratic nonpermutations" begin
        F = random_permutation_sbox(rng, Val(5))
        G = compositional_inverse(F)
        A = ccz_equivalence_certificate(F, G)
        @test is_invertible(A)
        @test ccz_equivalent_function(F, A) == G
        @test are_ccz_equivalent(F, G; on_inconclusive = :throw)
        F = SBox{4}(UInt8[0, 0, 0, 1, 0, 2, 4, 7, 0, 4, 6, 3, 8, 14, 11, 12])
        G = SBox{4}(UInt8[0, 1, 15, 8, 10, 12, 1, 1, 15, 10, 12, 15, 10, 8, 12, 8])
        @test ccz_equivalent_function(F, ccz_equivalence_certificate(F, G)) == G
        @test ccz_equivalence_certificate(kim_apn(), gold_apn(6, 1)) === nothing
        @test ea_equivalence_certificate(kim_apn(), dillon_apn_permutation()) === nothing
    end

    @testset "interruption policies do not invent negative certificates" begin
        F, G = gold_apn(4, 1), gold_apn(4, 1)
        for f in (are_ea_equivalent, are_ccz_equivalent)
            @test_throws InconclusiveEquivalence f(F, G; strategy = :partition_refinement,
                max_nodes = 0, on_inconclusive = :throw)
            @test ismissing(f(F, G; strategy = :partition_refinement,
                max_nodes = 0, on_inconclusive = :missing))
            @test_logs (:warn, r"inconclusive") f(F, G; strategy = :partition_refinement,
                max_nodes = 0, on_inconclusive = :best_effort)
            @test_throws ArgumentError f(F, G; on_inconclusive = :invalid)
            @test_throws ArgumentError f(F, G; strategy = :invalid)
        end
        for f in (ea_equivalence_certificate, ccz_equivalence_certificate)
            @test_throws InconclusiveEquivalence f(F, G; max_nodes = 0)
            @test ismissing(f(F, G; max_nodes = 0, on_inconclusive = :missing))
        end
        # The legacy mixed quadratic branch must honor its representative cap.
        @test ismissing(are_ccz_equivalent(kim_apn(), dillon_apn_permutation();
            strategy = :canteaut_perrin, max_class_reps = 0, on_inconclusive = :missing))
        wide = SBox{4,UInt16}(UInt16.(F.lut))
        @test are_ccz_equivalent(F, wide; strategy = :partition_refinement)
        @test are_ea_equivalent(F, wide; strategy = :partition_refinement)
        @test ea_equivalence_certificate(F, wide) !== nothing
    end
end
