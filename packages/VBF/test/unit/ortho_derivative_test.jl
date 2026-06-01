@testitem "ortho_derivative" begin
using VBFCatalog
using VBF
using Test

@testset "ortho_derivative: nothing for non-APN functions" begin
    F = load_literature_sbox("PRESENT")   # DU=4, not APN
    @test differential_uniformity(F) > 2
    @test ortho_derivative(F) === nothing
    @test !is_quadratic_apn(F)
end

@testset "ortho_derivative: defined for quadratic APN" begin
    # n=4: F = x^3 over GF(2⁴) is a quadratic APN.
    F = load_apn_function("n4_Gold_x3")
    π = ortho_derivative(F)
    @test π !== nothing
    @test π isa SBox{inputbits(F), storage_type(F)}
    @test π.lut[1] == 0   # π_F(0) = 0 by convention
    @test is_quadratic_apn(F)
end

@testset "ortho_derivative: not defined for non-quadratic APN" begin
    # n5_Kasami_x15 = x^15 over GF(2⁵) has algebraic degree 4, so its ortho-derivative is undefined.
    F = load_apn_function("n5_Kasami_x15")
    @test algebraic_degree(F) > 2
    @test ortho_derivative(F) === nothing
end

@testset "ortho_derivative: defining property — π is dual to the linear part of D_a F" begin
    for name in ("n4_Gold_x3", "n5_Gold_x3", "n5_Gold_x5")
        F = load_apn_function(name)
        π = ortho_derivative(F)
        @test π !== nothing
        N = inputbits(F)
        n_size = 1 << N
        for a in 1:(n_size - 1)
            pa = Int(π.lut[a + 1])
            for x in 0:(n_size - 1)
                d_x = Int(F.lut[x + 1] ⊻ F.lut[(x ⊻ a) + 1])
                for y in 0:(n_size - 1)
                    d_y = Int(F.lut[y + 1] ⊻ F.lut[(y ⊻ a) + 1])
                    @test (count_ones(UInt(pa) & UInt(d_x ⊻ d_y)) & 1) == 0
                end
            end
        end
    end
end

@testset "ortho_derivative: identity (π_F)² ≡ … is an APN itself" begin
    # The ortho-derivative is generally a quadratic APN itself (Canteaut-Charpin-Kyureghyan). Spot-check on n=4 Gold x^3.
    F = load_apn_function("n4_Gold_x3")
    π = ortho_derivative(F)
    @test π !== nothing
    @test differential_uniformity(π) == 2
end

@testset "ortho_derivative: distinguishes Frobenius orbits at n=5 (quadratic APN)" begin
    F3 = load_apn_function("n5_Gold_x3")
    F5 = load_apn_function("n5_Gold_x5")
    π3 = ortho_derivative(F3)
    π5 = ortho_derivative(F5)
    @test π3 !== nothing
    @test π5 !== nothing
    @test !are_linear_equivalent(π3, π5; strategy = :stennes)
end

@testset "ortho_derivative: reflexivity" begin
    # F ~_L F always; π_F is a deterministic function of F's LUT.
    F = load_apn_function("n5_Gold_x3")
    π1 = ortho_derivative(F)
    π2 = ortho_derivative(F)
    @test π1 == π2
end

end
