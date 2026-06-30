@testset "construction1_test" begin
    include(joinpath(@__DIR__, "..", "construction1.jl"))

    # safe_inv: 0^{-1} = 0, 1^{-1} = 1
    @test safe_inv(0, 6) == 0
    @test safe_inv(1, 6) == 1

    # U_max for n=6: nonempty, even cardinality, closed under x -> x+1
    u6 = build_u_max(6)
    @test length(u6) == 14              # paper states 14 elements for n=6
    @test iseven(length(u6))
    u6_set = Set(u6)
    for x in u6
        @test (x ⊻ 1) ∈ u6_set         # condition a)
        @test gf_trace(safe_inv(x, 6), 6) == 1   # condition b)
    end

    # Construction 1 gives a bijection
    F6 = construction1_sbox(6, u6)
    @test is_permutation(F6)

    # Theorem 1: differentially 4-uniform
    @test differential_uniformity(F6) == 4

    # Smallest valid U (one pair)
    pairs = u_max_pairs(u6)
    u_small = [pairs[1][1], pairs[1][2]]
    @test validate_u(u_small, 6)
    F_small = construction1_sbox(6, u_small)
    @test is_permutation(F_small)
    @test differential_uniformity(F_small) == 4
end
