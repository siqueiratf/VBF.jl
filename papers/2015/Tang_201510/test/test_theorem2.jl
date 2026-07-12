@testset "theorem2_test" begin
    include(joinpath(@__DIR__, "..", "theorem2.jl"))

    # Theorem 2: algebraic degree = n-1 for n=6
    u6 = build_u_max(6)
    F6 = construction1_sbox(6, u6)
    @test algebraic_degree(F6) == 5

    # Also verify with smallest valid U
    pairs = u_max_pairs(u6)
    u_small = [pairs[1][1], pairs[1][2]]
    F_small = construction1_sbox(6, u_small)
    @test algebraic_degree(F_small) == 5
end
