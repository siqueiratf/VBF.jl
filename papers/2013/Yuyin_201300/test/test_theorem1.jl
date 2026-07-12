@testset "theorem1_test" begin
    include(joinpath(@__DIR__, "..", "theorem1.jl"))

    # Exhaustive check for m=2 (n=4): 105 pairs
    n = 4; mod = primitive_polynomial(n); N = 1 << n
    count4 = 0
    for u in 1:N-1, v in u+1:N-1
        pred = theorem1_predict(u, v, n, mod)
        actual = differential_uniformity(inverse_swap(u, v, n; modulus=mod))
        @test actual == pred.predicted
        actual == 4 && (count4 += 1)
    end
    @test count4 == 30

    # Remark 2 example: I_{(g, g^12)} on n=8
    n8 = 8; mod8 = conway_polynomial(n8)
    g12 = gf_pow(2, 12, n8; modulus=mod8)
    G = inverse_swap(2, g12, n8; modulus=mod8)
    @test differential_uniformity(G) == 4
    @test nonlinearity(G) == 110

    # Trace condition for this example
    pred = theorem1_predict(2, g12, n8, mod8)
    @test pred.tr_uv == 1
    @test pred.tr_vu == 1
end
