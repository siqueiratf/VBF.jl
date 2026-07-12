@testset "theorem4_test" begin
    include(joinpath(@__DIR__, "..", "theorem4.jl"))

    # F₃ and F₄ share mugshot for several APN instances on half=4, m=1
    n, m = 4, 1
    mod = primitive_polynomial(n)
    e = (1 << m) + 1
    count = 0
    for a = 0:(1<<n)-1, b = 1:(1<<n)-1
        # only APN instances
        rootless = !any(
            gf_pow(x, e, n; modulus=mod) ⊻ gf_mul(a, x, n; modulus=mod) ⊻ b == 0
            for x = 0:(1<<n)-1
        )
        rootless || continue
        r = theorem4_verify(; half=4, m=1, a, b)
        @test r.ok
        count += 1
    end
    @test count > 0  # at least some APN pairs existed

    # Round-trip: F₄ on same admissible (a,b) should also be APN
    # (same condition P rootless)
    F3 = taniguchi_apn(4, 1, 2, 5)
    F4 = taniguchi_thm4(4, 1, 2, 5)
    # Find if these are admissible
    is_admissible = _P_rootless(4, 1, 2, 5)
    if is_admissible
        @test differential_uniformity(F3) == 2
        @test differential_uniformity(F4) == 2
        @test apn_ea_mugshot(F3) == apn_ea_mugshot(F4)
    end
end
