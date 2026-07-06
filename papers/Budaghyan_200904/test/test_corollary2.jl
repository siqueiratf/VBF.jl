@testset "corollary2_test" begin
    include(joinpath(@__DIR__, "..", "corollary2.jl"))

    # Small budget: verify F, F' and F'=(F)^{2^m} at n=4 (m=2).
    n, m = 4, 2
    M = primitive_polynomial(n)
    F  = x3_plus_reltrace(n, m; modulus = M)
    Fp = x3_plus_reltrace_cubed(n, m; modulus = M)
    @test differential_uniformity(F) == 2                    # APN
    @test differential_uniformity(Fp) == 2
    @test all(Fp.lut[x+1] == gf_pow(F.lut[x+1], 1 << m, n; modulus = M) for x = 0:((1 << n) - 1))  # F'=F^{2^m}
end
