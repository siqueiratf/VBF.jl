@testset "theorem3_1_test" begin
    include(joinpath(@__DIR__, "..", "theorem3_1.jl"))

    # m=2, n=4: spot-check two (i,c) pairs exhaustively
    mod4 = primitive_polynomial(4)
    d    = first(x for x in 1:15 if gf_pow(x, 4, 4; modulus = mod4) != x)

    # i=1 (only valid i for m=2)
    for c in 0:15
        cond = hexanomial_condition(2, 1, c; modulus = mod4)
        H    = hexanomial_sbox(2, 1, c, d; modulus = mod4)
        @test cond == (differential_uniformity(H) == 2)
    end

    # Full m=2 report should pass
    r = theorem3_1_report(devnull; ms = [2])
    @test r.all_ok
    @test r.results[2].fail_count == 0
end
