@testset "table4_power_map_self_equivalences" begin
    include(joinpath(@__DIR__, "..", "table4.jl"))

    # Table 4's three s values are n · (2ⁿ − 1) for the corresponding n.
    @test [s for (_, _, _, s, _) in TABLE4] == [2040, 889, 4599]
    for (_, _, n, s, d) in TABLE4
        @test n * ((1 << n) - 1) == s
        @test gcd(d, (1 << n) - 1) == 1          # so xᵈ is a permutation
    end

    # Constructive lower bound: n(2ⁿ−1) valid, pairwise distinct pairs.
    for (_, _, n, s, d) in TABLE4
        F = power_permutation(n, d)
        pairs = power_map_self_equivalences(n, d)
        @test length(pairs) == s
        @test all(is_power_self_equivalence(F, p.A1, p.A2) for p in pairs)
        @test length(Set((copy(p.A1.cols), copy(p.A2.cols)) for p in pairs)) == s
    end

    # 2040 = 8 × 255 also matches the Rijndael row derived in section4.jl.
    @test length(power_map_self_equivalences(8, 254)) == 2040

    # x^d must be a permutation for the construction to apply.
    @test_throws ArgumentError power_permutation(8, 3)   # gcd(3, 255) = 3

    # Report passes on the fast path.
    @test table4_report(devnull; full_search = false)
end
