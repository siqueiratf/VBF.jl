@testset "theorem17_test" begin
    include(joinpath(@__DIR__, "..", "helpers.jl"))
    using VBFCatalog

    # Gold x^3 n=5: F(0)=0, F(1)=1; Theorem 17 condition must FAIL for n>=5
    s5 = load_apn_function("n5_Gold_x3")
    r5 = theorem17_holds(s5)
    @test !r5.holds
    @test r5.dd10 >= 0
    @test r5.s1 >= 0
    @test r5.s2 >= 0

    # Gold x^3 n=6: also must fail
    s6 = load_apn_function("n6_Gold_x3")
    r6 = theorem17_holds(s6)
    @test !r6.holds

    # Round-trip: normalize_apn leaves power functions unchanged
    @test normalize_apn(s5).lut == s5.lut
    @test normalize_apn(s6).lut == s6.lut

    # Sanity: S1, S2 are non-negative integers
    @test r5.s1 isa Int && r5.s1 >= 0
    @test r5.s2 isa Int && r5.s2 >= 0
end
