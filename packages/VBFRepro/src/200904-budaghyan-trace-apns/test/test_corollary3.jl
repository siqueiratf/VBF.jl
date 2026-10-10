@testset "corollary3_test" begin
    include(joinpath(@__DIR__, "..", "corollary3.jl"))

    F = apn_x3_tr_x9(7)
    @test algebraic_degree(F) == 2                            # F is quadratic
    @test !are_ea_equivalent(F, gold_apn(7, 1))              # EA-inequiv to Gold
    r = corollary3_report(devnull; n = 7)
    @test r.all_ok
end
