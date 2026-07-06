@testset "theorem3_test" begin
    include(joinpath(@__DIR__, "..", "theorem3.jl"))

    # n=7: x³+tr(x⁹) is CCZ-inequivalent to Gold (quadratic ⇒ ortho-derivative EA).
    F = apn_x3_tr_x9(7)
    @test differential_uniformity(F) == 2                     # APN
    @test !are_ccz_equivalent(F, gold_apn(7, 1))             # CCZ-inequivalent
    r = theorem3_report(devnull; n = 7)
    @test r.all_inequiv
end
