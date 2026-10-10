@testset "theorem1_test" begin
    include(joinpath(@__DIR__, "..", "theorem1.jl"))
    result = theorem1_examples()
    for (desc, ok) in result.checks
        @test ok
    end

    # Non-vacuity: the sweep must have exercised both sides of Theorem 1's iff.
    # A sweep of APN-only inputs could not distinguish Theorem 1 from `is_qam`.
    @test result.n_total >= 100
    @test result.n_apn > 0                                    # some APN
    @test any(d > 2 for (d, _) in result.delta_histogram)     # and some NOT APN
    @test length(result.delta_histogram) >= 4                 # δ spans ≥ 4 values

    # Direct spot-checks against known functions, independent of the random sweep.
    for n = 4:7
        gold = sbox_from_exponents(n, [3])                    # x³ is APN for all these n
        @test theorem1_delta(gold) == 2
        @test theorem1_delta(gold) == differential_uniformity(gold)
    end

    # NON-APN quadratics: Theorem 1 must predict δ correctly for these too — not just
    # return 2 for everything. Collect the non-APN homogeneous quadratics over GF(2⁵)
    # among all subsets of {x³, x⁵, x⁶, x⁹, x¹⁰, x¹², x¹⁷, x¹⁸, x²⁰, x²⁴}.
    n = 5
    E = [3, 5, 6, 9, 10, 12, 17, 18, 20, 24]
    non_apn = SBox{n,VBF._storage_for(n)}[]
    for mask = 1:((1<<length(E))-1)
        exps = [E[i] for i = 1:length(E) if (mask >> (i - 1)) & 1 == 1]
        F = sbox_from_exponents(n, exps)
        all(x -> Int(F(x)) == 0, 0:((1<<n)-1)) && continue
        differential_uniformity(F) > 2 && push!(non_apn, F)
    end
    @test !isempty(non_apn)                                   # the check has teeth
    @test all(theorem1_delta(F) == differential_uniformity(F) for F in non_apn)
    @test all(theorem1_delta(F) != 2 for F in non_apn)
    @test all(!is_qam(quadratic_apn_matrix(F)) for F in non_apn)
end
