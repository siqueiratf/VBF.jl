@testset "proposition3_test" begin
    include(joinpath(@__DIR__, "..", "proposition3.jl"))

    # Formula matches swap for m=2 (n=4)
    n = 4; mod = primitive_polynomial(n); N = 1 << n
    for v in 1:N-1
        G = inverse_swap(0, v, n; modulus=mod)
        lut_f = [i0v_formula(x, v, n, mod) for x in 0:N-1]
        @test collect(Int, G.lut) == lut_f
    end

    # δ=6 for m=2 (even), δ≤4 for m=3 (odd)
    for v in 1:N-1
        @test differential_uniformity(inverse_swap(0, v, 4; modulus=primitive_polynomial(4))) == 6
    end

    n6 = 6; mod6 = primitive_polynomial(n6)
    for v in [1, 2, 5, 10]
        @test differential_uniformity(inverse_swap(0, v, n6; modulus=mod6)) <= 4
    end

    # Remark 1 nonlinearity
    @test nonlinearity(inverse_swap(0, 1, 6; modulus=primitive_polynomial(6))) == 24
    @test nonlinearity(inverse_swap(0, 1, 8; modulus=primitive_polynomial(8))) == 112
end
