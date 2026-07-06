@testset "corollary3_test" begin
    include(joinpath(@__DIR__, "..", "corollary3.jl"))
    r = corollary3_report(devnull; full_search = false)
    @test r.all_ok
    # New-class claim: n=6 x³+trₙ(x⁹) CCZ-inequivalent to x³+α⁻¹trₙ(α³x⁹).
    @test all(nc -> nc[2], r.newclass)
    s1 = od_signature(apn_eq6(6, 1), 6)
    sa = od_signature(apn_eq6(6, primitive_element(6)), 6)
    @test s1 != sa
end
