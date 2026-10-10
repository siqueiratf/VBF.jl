@testset "proposition1_test" begin
    include(joinpath(@__DIR__, "..", "proposition1.jl"))

    # Proposition 1 (tex:184) is ONE-DIRECTIONAL: E_i trivial ⇒ C_i APN.
    # Full sweep over i = 1..9 at n=10, k=0.
    results = check_proposition1(10)
    @test length(results) == 9
    @test all(r -> r.sufficient, results)            # the paper's claim

    # Non-vacuity: the hypothesis is not vacuously true — it holds for exactly 4
    # of the 9 i-values, so the implication has a live antecedent AND a live
    # negative branch.
    @test count(r -> r.ei_trivial, results) == 4
    @test count(r -> !r.ei_trivial, results) == 5
    @test [r.i for r in results if r.ei_trivial] == [3, 5, 7, 9]

    # Nor is the conclusion vacuously true: 5 of the 9 C_i are NOT APN.
    @test count(r -> !r.is_apn, results) == 5

    # The converse (APN ⇒ E_i trivial) is NOT claimed by the paper. It happens to
    # hold over GF(2^10) for k = 0..3 — recorded here as an observation, kept out
    # of the Proposition 1 assertions above.
    for k in 0:3
        rs = check_proposition1(10; k)
        @test all(r -> r.sufficient, rs)
        @test all(r -> r.converse, rs)
    end

    # Theorem 2's i-list is NOT the set of all APN i-values once k is odd: at k=1,
    # i=1 is APN although 1 ∉ {3,5,7,9}. This is why a blanket biconditional
    # against the Theorem 2 list would be an overclaim.
    rs1 = check_proposition1(10; k = 1)
    @test [r.i for r in rs1 if r.is_apn] == [1, 3, 5, 7]
    @test differential_uniformity(build_ci_sbox(10, 1, 1)) == 2   # APN at k=1
    @test differential_uniformity(build_ci_sbox(10, 1, 0)) == 32  # not APN at k=0
end
