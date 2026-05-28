using BFA
using Test

@testset "ortho_integral: round-trip ortho_derivative(ortho_integral(πF)) == πF" begin
    # ortho_integral is determined only up to adding a linear function,
    # which the ortho-derivative is invariant under. So the OUTER round
    # trip must hold exactly even if the recovered Q differs from the
    # original by a linear term.
    for name in ("n4_Gold_x3", "n5_Gold_x3", "n5_Gold_x5")
        F = load_apn_function(name)
        π = ortho_derivative(F)
        @test π !== nothing
        Q = ortho_integral(π)
        @test Q !== nothing
        @test is_quadratic_apn(Q)
        @test ortho_derivative(Q) == π
    end
end

@testset "ortho_integral: recovered Q is a quadratic APN" begin
    F = load_apn_function("n4_Gold_x3")
    π = ortho_derivative(F)
    Q = ortho_integral(π)
    @test Q !== nothing
    @test differential_uniformity(Q) == 2
    @test algebraic_degree(Q) == 2
    @test Q.lut[1] == 0   # the system pins Q(0) = 0
end

@testset "ortho_integral: type preserved" begin
    F = load_apn_function("n5_Gold_x3")
    π = ortho_derivative(F)
    Q = ortho_integral(π)
    @test Q isa SBox{5, UInt8}
end
