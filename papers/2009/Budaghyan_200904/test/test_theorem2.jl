@testset "theorem2_test" begin
    include(joinpath(@__DIR__, "..", "theorem2.jl"))

    # Small budget: verify the n=4 (m=2) construction directly (report also does n=8).
    n, m = 4, 2
    F = x3_plus_reltrace(n, m)
    @test differential_uniformity(F) == 2                    # APN
    e = (1 << m) + 2
    @test all(in_subfield(gf_relative_trace(gf_pow(x, e, n), n, m), m, n) for x = 0:((1 << n) - 1))
end
