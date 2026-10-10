@testset "theorem1_test" begin
    include(joinpath(@__DIR__, "..", "theorem1.jl"))

    modulus6  = primitive_polynomial(6)
    modulus12 = primitive_polynomial(12)

    # n=6, k=2, s=1 — Family 1 (v=w=0): binomial, identical to Budaghyan et al. Family 1
    F1_6 = theorem1_sbox(2, 1, 0, 0; modulus = modulus6)
    @test differential_uniformity(F1_6) == 2

    # Family 7 (v=0, w≠0): trinomial
    F7_6 = theorem1_sbox(2, 1, 0, 1; modulus = modulus6)
    @test differential_uniformity(F7_6) == 2

    # Family 8W (v≠0, w=0): trinomial (new)
    F8W_6 = theorem1_sbox(2, 1, 1, 0; modulus = modulus6)
    @test differential_uniformity(F8W_6) == 2

    # Family 8 (v≠0, w≠0, vw≠1): quadrinomial (new); check vw≠1 explicitly
    v6 = subfield_elem(6, 2, 0; modulus = modulus6)   # u^21 ∈ GF(4)
    w6 = subfield_elem(6, 2, 1; modulus = modulus6)   # u^42 ∈ GF(4)
    @test gf_mul(v6, w6, 6; modulus = modulus6) != 1
    F8_6 = theorem1_sbox(2, 1, 1, 2; modulus = modulus6)
    @test differential_uniformity(F8_6) == 2

    # Round-trip: Family 1 at n=6 matches pure monomial binomial u^4·x^24 + u·x^3
    u = 2
    c1 = gf_pow(u, 4, 6; modulus = modulus6)   # u^{2^2}
    lut_ref = [gf_mul(c1, gf_pow(x, 24, 6; modulus = modulus6), 6; modulus = modulus6) ⊻
               gf_mul(u,  gf_pow(x,  3, 6; modulus = modulus6), 6; modulus = modulus6)
               for x in 0:63]
    @test SBox(lut_ref) == F1_6

    sweep = theorem1_parameter_sweep(2, 1; full_search=true, io=devnull)
    @test sweep.outcome isa Exhausted
    @test sweep.parameter_pairs == 13
    @test all(row.quadratic_apn for row in sweep.records)
    partial = theorem1_parameter_sweep(4, 11; limit=1, io=devnull)
    @test partial.outcome isa BudgetHit
    @test partial.parameter_pairs == 241
    @test only(partial.records).quadratic_apn
    stopped = theorem1_parameter_sweep(4, 5; max_evaluations=0, io=devnull)
    @test isempty(stopped.records)
    @test stopped.outcome isa BudgetHit
    @test_throws ArgumentError theorem1_parameter_sweep(4, 1; io=devnull)
    @test_throws ArgumentError theorem1_parameter_sweep(4, -1; io=devnull)
    @test_throws ArgumentError theorem1_parameter_sweep(4, 65; io=devnull)
    @test_throws ArgumentError theorem1_sbox(4, 65, 1, 2)
    @test_throws ArgumentError theorem1_sbox(4, 5, -1, 2)

    # n=12, k=4, s=5 and s=11 — all four families APN
    for s in (5, 11), (vi, wi) in [(0,0), (0,1), (1,0), (1,5)]
        F = theorem1_sbox(4, s, vi, wi; modulus = modulus12)
        @test differential_uniformity(F) == 2
    end
end
