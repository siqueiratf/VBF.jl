@testset "theorem4_test" begin
    include(joinpath(@__DIR__, "..", "theorem4.jl"))

    n = 10; m = 5

    # Theorem 4 i-values for n=10
    pairs = theorem4_i_values(n)
    expected_is = [m - 2, m, invmod(m - 2, n), n - 1]  # [3, 5, 7, 9]
    @test [last(p) for p in pairs] == expected_is

    # Each Theorem 4 i-value: E_i trivial and C_i APN
    for (_, i) in pairs
        @test system_Ei_trivial(n, i)
        @test differential_uniformity(build_ci_sbox(n, i)) == 2
    end
end
