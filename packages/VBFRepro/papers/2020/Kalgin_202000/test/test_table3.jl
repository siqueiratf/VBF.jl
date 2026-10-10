@testset "table3_test" begin
    include(joinpath(@__DIR__, "..", "table3.jl"))

    # n=4 example
    F4 = stacked_n4()
    F4q = stacked_n4_quadpart()
    @test differential_uniformity(F4) == 2
    @test algebraic_degree(F4) == 3
    @test differential_uniformity(F4q) == 2
    @test algebraic_degree(F4q) == 2
    @test quadratic_part(F4) == F4q
    @test F4 != F4q

    # n=5 example
    F5 = stacked_n5()
    F5q = stacked_n5_quadpart()
    @test differential_uniformity(F5) == 2
    @test algebraic_degree(F5) == 3
    @test differential_uniformity(F5q) == 2
    @test algebraic_degree(F5q) == 2
    @test quadratic_part(F5) == F5q
    @test F5 != F5q

    # n=6 example
    F6 = stacked_n6()
    F6q = stacked_n6_quadpart()
    @test differential_uniformity(F6) == 2
    @test algebraic_degree(F6) == 3
    @test differential_uniformity(F6q) == 2
    @test algebraic_degree(F6q) == 2
    @test quadratic_part(F6) == F6q
    @test F6 != F6q

    # quadratic_part must actually strip degrees ≠ 2 — otherwise every assertion
    # above about F^(2) would be about F itself.
    @test algebraic_degree(quadratic_part(F6)) == 2
    @test quadratic_part(quadratic_part(F6)) == quadratic_part(F6)   # idempotent
    @test quadratic_part(F6)(0) == 0                                 # no constant term
    @test quadratic_part(inverse_apn(5)) != inverse_apn(5)

    # ── §6.1 — Δ of the quadratic part of non-quadratic APN functions ────────
    # "For the Dillon APN permutation P of F_2^6 the value Δ_{P^(2)} is equal to 8.
    #  When n = 8, 9 there also exist APN functions F (e.g. the Kasami power
    #  functions for n = 8 and the inverse function for n = 9) such that
    #  Δ_{F^(2)} = 8."
    claims = quadratic_part_claims_6_1()
    @test length(claims) == 3
    for c in claims
        @test c.du_F == 2            # each F is APN…
        @test c.deg_F > 2            # …and NOT quadratic (otherwise F^(2) = F)
        @test c.deg_Q == 2           # its quadratic part is quadratic
        @test c.du_Q == 8            # the paper's number
        @test c.du_Q == c.expected_du_Q
    end
    # spelled out, so a silent change of the helper cannot pass unnoticed
    @test differential_uniformity(quadratic_part(dillon_apn_permutation())) == 8
    @test differential_uniformity(quadratic_part(kasami_apn(8, 3))) == 8
    @test differential_uniformity(quadratic_part(inverse_apn(9))) == 8
    # Kasami at n=8 needs gcd(k,8)=1; VBF's default k=2 is invalid there
    @test_throws ArgumentError kasami_apn(8)

    # Proposition 4: an APN F on F_2^4 has Δ_{F^(2)} ≤ 4 (spot-check on the n=4
    # APN functions we have; 8 would violate it)
    @test differential_uniformity(quadratic_part(gold_apn(4))) <= 4
    @test differential_uniformity(quadratic_part(stacked_n4())) <= 4

    # ── §6.2 — the explicit n=6 example C = F + h·e_1 ────────────────────────
    C = switching_example_n6()
    @test C isa SBox{6}
    @test differential_uniformity(C) == 2      # C is APN
    @test algebraic_degree(C) == 3             # …and cubic
    CQ = quadratic_part(C)
    @test differential_uniformity(CQ) == 2     # its quadratic part is APN too
    @test algebraic_degree(CQ) == 2
    @test C != CQ
    # h is a SINGLE homogeneous cubic term riding on coordinate c_1 (x2x3x5), so
    # C and its quadratic part differ only in the first output bit.
    @test all((C(x) ⊻ CQ(x)) & ~0x01 == 0 for x = 0:63)
    @test any(C(x) != CQ(x) for x = 0:63)
    # …which makes C a stacked cubic APN in the sense of Definition 1
    @test differential_uniformity(C) == 2 && differential_uniformity(quadratic_part(C)) == 2
end
