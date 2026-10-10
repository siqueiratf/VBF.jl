@testset "theorem2_test" begin
    include(joinpath(@__DIR__, "..", "theorem2.jl"))

    @test verify_theorem2(n = 4)

    # Verify directly for one shift
    n = 4; mod = conway_polynomial(n)
    b = find_normal_element(n; modulus = mod)
    F = SBox{n}([gf_pow(x, 3, n; modulus = mod) for x in 0:(1<<n)-1])
    MF = normal_basis_deriv_matrix(F, b; modulus = mod)

    s = 1
    Fprime = SBox{n}([gf_pow(x, 3 * (1 << s), n; modulus = mod) for x in 0:(1<<n)-1])
    MFprime = normal_basis_deriv_matrix(Fprime, b; modulus = mod)
    @test MFprime == cyclic_shift_matrix(MF, s)

    # Shift by s=2
    s2 = 2
    Fprime2 = SBox{n}([gf_pow(x, 3 * (1 << s2), n; modulus = mod) for x in 0:(1<<n)-1])
    MFprime2 = normal_basis_deriv_matrix(Fprime2, b; modulus = mod)
    @test MFprime2 == cyclic_shift_matrix(MF, s2)

    # Cyclic shift by n = identity
    @test cyclic_shift_matrix(MF, n) == MF
end
