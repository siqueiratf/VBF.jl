@testset "theorem1_test" begin
    include(joinpath(@__DIR__, "..", "theorem1.jl"))

    # Gold x^3 (k=1) satisfies the diagonal-squaring property for n=5 and n=6
    for n in (5, 6)
        mod = conway_polynomial(n)
        b   = find_normal_element(n; modulus = mod)
        F   = polynomial_sbox(n, [3]; modulus = mod)
        H   = normal_basis_deriv_matrix(F, b; modulus = mod)
        ok, _ = verify_diagonal_squaring(H, n; modulus = mod)
        @test ok
    end

    # Gold x^9 (k=3) also satisfies for n=5 (gcd(3,5)=1)
    let n = 5, mod = conway_polynomial(5)
        b = find_normal_element(n; modulus = mod)
        F = polynomial_sbox(n, [9]; modulus = mod)
        H = normal_basis_deriv_matrix(F, b; modulus = mod)
        ok, _ = verify_diagonal_squaring(H, n; modulus = mod)
        @test ok
    end
end
