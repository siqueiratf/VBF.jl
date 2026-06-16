@testset "corollary3_14" begin
    include(joinpath(@__DIR__, "..", "corollary3_14.jl"))

    # Gold x^3 n=5 (APN): all nonzero a have rank 4 = n-1
    F5 = gold_apn(5)
    @test verify_corollary3_14_apn(F5)

    # Gold x^3 n=6 (APN)
    F6 = gold_apn(6)
    @test verify_corollary3_14_apn(F6)

    # Non-APN check: n=6 x^5 is NOT APN (diff-unif > 2)
    lut6 = gf_monomial_lut(6, 5)
    G6 = SBox{6,UInt8}(UInt8.(lut6))
    if differential_uniformity(G6) != 2
        @test verify_corollary3_14_non_apn(G6)
    end

    # For n=5, x^5 IS APN (Gold i=2): verify rank n-1 for all nonzero a
    lut5 = gf_monomial_lut(5, 5)
    G5 = SBox{5,UInt8}(UInt8.(lut5))
    if differential_uniformity(G5) == 2
        @test verify_corollary3_14_apn(G5)
    end
end
