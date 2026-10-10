@testset "theorem2_test" begin
    include(joinpath(@__DIR__, "..", "theorem2.jl"))

    n = 10; m = 5

    # Theorem 2 (tex:256) i-values for n=10: {m-2, m, (m-2)^-1 mod n, n-1}
    pairs = theorem2_i_values(n)
    expected_is = [m - 2, m, invmod(m - 2, n), n - 1]  # [3, 5, 7, 9]
    @test [last(p) for p in pairs] == expected_is

    # Each Theorem 2 i-value: E_i trivial and C_i APN
    for (_, i) in pairs
        @test system_Ei_trivial(n, i)
        @test differential_uniformity(build_ci_sbox(n, i)) == 2
    end

    # Tightness (non-vacuity): every OTHER i has non-trivial E_i solutions and is
    # not APN. Without this, the theorem could be "satisfied" by an i-set that is
    # simply all of 1..n-1.
    others = [i for i in 1:n-1 if i ∉ Set(expected_is)]   # [1,2,4,6,8]
    @test length(others) == 5
    for i in others
        @test !system_Ei_trivial(n, i)
        @test differential_uniformity(build_ci_sbox(n, i)) != 2
    end

    # tex:421: for even k the Theorem 2 values are the ONLY APN ones. Checked at
    # n=10 and — new — at n=14 (m=7 odd, 3∤7), where the four values are
    # {m-2, m, (m-2)^-1 mod 14, n-1} = {5, 7, 3, 13}.
    @test apn_i_values(10) == [3, 5, 7, 9]
    @test sort(collect(Set(last(p) for p in theorem2_i_values(14)))) == [3, 5, 7, 13]
    @test apn_i_values(14) == [3, 5, 7, 13]

    # Only the parity of k matters on the even-k branch: system (16) ⇔ (2)
    @test apn_i_values(10; k = 2) == [3, 5, 7, 9]

    # Hypothesis guard: m must be odd with 3 ∤ m
    @test_throws ErrorException theorem2_i_values(12)  # m=6, even
    @test_throws ErrorException theorem2_i_values(6)   # m=3, 3|m
end
