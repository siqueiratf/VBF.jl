@testset "theorem3_test" begin
    include(joinpath(@__DIR__, "..", "theorem3.jl"))

    n = 6

    u_max = build_u_max(n)
    pairs = u_max_pairs(u_max)
    u_small = [pairs[1][1], pairs[1][2]]

    # Theorem 3: NL >= 2^{n-1} - 2^{n/2} - |U|
    F_small = construction1_sbox(n, u_small)
    @test nonlinearity(F_small) >= nl_bound_thm3(n, 2)

    # Theorem 4: U = U_max => NL >= 2^{n-1} - 3*2^{n/2} - 2
    F_max = construction1_sbox(n, u_max)
    @test nonlinearity(F_max) >= nl_bound_thm4(n)

    # Theorem 5: U = U_{m0} => NL >= 2^{n-1} - 2^{n/2+2} - 2
    u_m0 = build_u_m0(n)
    F_m0 = construction1_sbox(n, u_m0)
    @test nonlinearity(F_m0) >= nl_bound_thm5(n)

    # Theorem 6: U = U_{m1} => NL >= 2^{n-1} - 2^{n/2+2} - 2
    u_m1 = build_u_m1(n)
    F_m1 = construction1_sbox(n, u_m1)
    @test nonlinearity(F_m1) >= nl_bound_thm6(n)

    # U_max = U_{m0} union U_{m1}
    @test sort(u_max) == sort(vcat(u_m0, u_m1))
end
