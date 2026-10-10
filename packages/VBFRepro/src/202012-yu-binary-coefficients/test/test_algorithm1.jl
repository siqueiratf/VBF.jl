@testset "algorithm1_test" begin
    include(joinpath(@__DIR__, "..", "algorithm1.jl"))
    include(joinpath(@__DIR__, "..", "table2.jl"))

    # ── n=6: exhaustive search must find exactly 1 EA-class (x³) ──────────────
    outcome6 = algorithm1_run(6; max_evaluations = 1 << 24)
    # The sweep must have actually finished for the count to test the paper's
    # figure rather than the budget.
    @test is_exhausted(outcome6)
    classes6 = search_solutions(outcome6)
    @test length(classes6) == 1
    @test differential_uniformity(classes6[1]) == 2
    @test apn_ea_mugshot(classes6[1]) == apn_ea_mugshot(sbox_from_exponents(6, [3]))

    # NOTE: the old round-trip assertion here —
    #   @test has_f2_cyclic_structure(quadratic_apn_matrix(classes6[1]), 6)
    # — was a TAUTOLOGY: classes6[1] is qam_to_sbox(M) for a matrix M that
    # qam_from_cyclic built with that very structure, and quadratic_apn_matrix is the
    # inverse of qam_to_sbox. It could not fail. Removed; theorem2.jl now asserts the
    # substantive (and failing!) direction instead.

    # ── n=7: THE CLASSIFICATION TEST ──────────────────────────────────────────
    # This exhaustive sweep (~16 s) used to be run and then thrown away with no
    # assertion at all. It is the one place the paper's classification can actually be
    # tested, so it is tested here.
    outcome7 = algorithm1_run(7; max_evaluations = 1 << 24)
    @test is_exhausted(outcome7)
    classes7 = search_solutions(outcome7)

    # 14, not 15: search_qam de-duplicates by apn_ea_mugshot, which merges the
    # CCZ-inequivalent Gold pair x³/x⁹. This length is a LOWER BOUND on the CCZ count.
    @test length(classes7) == 14

    @test all(differential_uniformity(F) == 2 for F in classes7)
    @test all(algebraic_degree(F) == 2 for F in classes7)
    @test all(is_almost_bent(F) for F in classes7)          # every n=7 class is AB

    # The real content: the exhaustively-found σ-classes are EXACTLY the σ-classes of the
    # 15 Table-2 representatives (15 reps → 14 σ, the Gold pair x³/x⁹ sharing one).
    # This is what independently VALIDATES THE RECOVERED 15th ROW: if x³+x⁵+x⁹+x⁴⁰+x⁹⁶
    # were the wrong function, or if a class were missing, these two sets would differ.
    found_sigmas = Set(sigma_hash(F) for F in classes7)
    table2_sigmas = Set(sigma_hash(sbox_from_exponents(7, exps))
                        for (exps, _) in TABLE2_FUNCTIONS)
    @test length(found_sigmas) == 14
    @test length(table2_sigmas) == 14
    @test found_sigmas == table2_sigmas

    # Mutation guard — the equality above MUST be able to fail. Drop the recovered
    # representative and the σ-set shrinks to 13, which is no longer what the search
    # found. (If this test passed with the recovered row omitted, the assertion above
    # would be worthless.)
    sigmas_without_recovered = Set(sigma_hash(sbox_from_exponents(7, exps))
                                   for (exps, _) in TABLE2_FUNCTIONS[1:14])
    @test length(sigmas_without_recovered) == 13
    @test found_sigmas != sigmas_without_recovered
    @test setdiff(found_sigmas, sigmas_without_recovered) ==
          Set([sigma_hash(sbox_from_exponents(7, [3, 5, 9, 40, 96]))])
end

@testset "Algorithm1 traversal preserves uncertainty" begin
    bounded = algorithm1_run(6; max_evaluations = 1)
    @test bounded isa BudgetHit
    @test !proves_emptiness(bounded)
    timed = algorithm1_run(6; timeout_seconds = 0)
    @test timed isa BudgetHit
    @test !is_exhausted(timed)
    confirmed = algorithm1_run(3; confirm = true, max_evaluations = 10000)
    @test confirmed isa Exhausted
    @test confirmed.region.params["solution_unit"] == "ea_class"
end

@testset "Algorithm1 exact prefix pruning and Frobenius quotient" begin
    # Compare actual accepted matrices, before invariant bucketing. At n=5 the
    # complete nonzero cyclic-entry domain has 31² matrices; zero entries cannot
    # occur in a QAM, because its first row has n-1 independent nonzero entries.
    function matrices(n;prune,orbit_reduction)
        seen=Set{Tuple}()
        stats=algorithm1_search(n;prune,orbit_reduction,max_evaluations=100000,
            observer=(event,H)->push!(seen,Tuple(vec(H))))
        @test stats.outcome isa Exhausted
        (;seen,stats)
    end
    raw=matrices(5;prune=false,orbit_reduction=false)
    pruned=matrices(5;prune=true,orbit_reduction=false)
    @test !isempty(raw.seen)
    @test raw.seen == pruned.seen
    @test pruned.stats.final_tests < raw.stats.final_tests
    odometer=Set{Tuple}()
    for a in 0:31,b in 0:31
        H=qam_from_cyclic(5,1,[a,b])
        is_qam(H) && push!(odometer,Tuple(vec(H)))
    end
    @test odometer == raw.seen
    # Every retained orbit-representative APN expands to exactly the complete
    # accepted matrix set under entrywise Frobenius (Proposition 1).
    quotient=matrices(5;prune=true,orbit_reduction=true)
    expanded=Set{Tuple}()
    for H in quotient.seen,t in 0:4
        push!(expanded,Tuple(gf_pow(v,1 << t,5) for v in H))
    end
    @test expanded == raw.seen
    @test quotient.stats.prefixes < pruned.stats.prefixes
    @test !algorithm1_is_proper(zeros(Int,2,3),5)
    sample=reshape(collect(first(raw.seen)),5,5)
    @test algorithm1_is_proper(view(sample,1:2,1:3),5)
    @test rank_f2(UInt.(sample[1,2:end]);nbits=5)==4
    @test_throws ArgumentError algorithm1_run(1)
    @test_throws ArgumentError algorithm1_run(5;max_evaluations=-1)
    @test algorithm1_search(6;max_evaluations=0).implementation == :even_dimension_odometer
    @test !is_exhausted(algorithm1_run(5;max_evaluations=0))
end
