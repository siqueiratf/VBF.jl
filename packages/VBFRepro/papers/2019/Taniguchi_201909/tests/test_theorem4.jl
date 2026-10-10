@testset "theorem4_test" begin
    include(joinpath(@__DIR__, "..", "theorem4.jl"))

    # ── The paper's statement: an EXACT identity, not just an equivalence ──────
    # "Theorem 3 is obtained from Theorem 4 by the substitution x ↦ x^{2^{2m}}"
    # holds for ALL (a,b) with b≠0 — the non-APN members included.
    for (half, m) in [(4, 1), (4, 3), (5, 1), (5, 2)]
        r = theorem4_identity_verify(; half, m)
        @test r.ok
        @test r.fail == 0
        @test r.pass == (1 << half) * ((1 << half) - 1)   # every (a,b), b≠0
    end

    # Non-vacuity of that identity, three ways:
    #  (a) the substitution is not the identity map — F₃ and F₄ are different LUTs;
    #  (b) the WRONG substitution exponent (2^m, 2^{3m}) makes the check fail;
    #  (c) so the check is discriminating, not a tautology.
    @test taniguchi_apn(4, 1, 2, 5).lut != taniguchi_thm4(4, 1, 2, 5).lut
    @test theorem4_substitution_identity(; half=4, m=1, a=2, b=5)
    @test !theorem4_substitution_identity(; half=4, m=1, a=2, b=5, twist=1)   # 2^m
    @test !theorem4_substitution_identity(; half=4, m=1, a=2, b=5, twist=3)   # 2^{3m}

    # ── The (weaker) EA corollary: equal mugshots on the APN members ──────────
    n, m = 4, 1
    count = 0
    for a = 0:(1<<n)-1, b = 1:(1<<n)-1
        projective_polynomial_rootless(n, m, a, b) || continue   # APN members only
        r = theorem4_verify(; half=4, m=1, a, b)
        @test r.ok
        count += 1
    end
    @test count > 0  # at least some APN pairs existed

    # Round-trip: F₄ on the same admissible (a,b) is APN too (same P-rootless condition)
    F3 = taniguchi_apn(4, 1, 2, 5)
    F4 = taniguchi_thm4(4, 1, 2, 5)
    @test projective_polynomial_rootless(4, 1, 2, 5)
    @test differential_uniformity(F3) == 2
    @test differential_uniformity(F4) == 2
    @test apn_ea_mugshot(F3) == apn_ea_mugshot(F4)
end
