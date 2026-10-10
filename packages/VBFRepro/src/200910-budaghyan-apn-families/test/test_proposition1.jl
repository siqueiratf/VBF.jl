@testset "proposition1_test" begin
    include(joinpath(@__DIR__, "..", "proposition1.jl"))

    r = proposition1_report(devnull; full_search = false)
    @test r.all_ok

    # x + trₙ(x³) is a permutation and x³ + trₙ(x⁹) is APN, n=6.
    Llut = L_class_lut(:trace, 6)
    @test is_permutation(as_sbox(perm_from_L(Llut, 6), 6))
    @test differential_uniformity(as_sbox(apn_from_L(Llut, 6), 6)) == 2
end
