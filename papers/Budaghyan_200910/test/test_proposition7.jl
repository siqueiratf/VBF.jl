@testset "proposition7_test" begin
    include(joinpath(@__DIR__, "..", "proposition7.jl"))
    r = proposition7_report(devnull)
    @test r.all_ok
    # L=trₙ: vanishes on GF(2³) ⊂ GF(2⁶) and L²=0.
    Llut = L_class_lut(:trace, 6)
    @test all(a -> apply_L(Llut, a) == 0, subfield_elements(6, 3))
    @test all(x -> apply_L(Llut, apply_L(Llut, x)) == 0, 0:63)
end
