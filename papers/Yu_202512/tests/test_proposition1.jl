@testset "proposition1_test" begin
    include(joinpath(@__DIR__, "..", "proposition1.jl"))

    # For Gold x^3 at n=5: H and H^2 are both QAMs and are distinct
    let n = 5, mod = conway_polynomial(5)
        b  = find_normal_element(n; modulus = mod)
        F  = polynomial_sbox(n, [3]; modulus = mod)
        H  = normal_basis_deriv_matrix(F, b; modulus = mod)
        H2 = square_matrix(H, n; modulus = mod)
        @test is_qam(H)
        @test is_qam(H2)
        @test H != H2
    end
end
