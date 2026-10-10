@testset "proposition8_test" begin
    include(joinpath(@__DIR__, "..", "proposition8.jl"))
    r = proposition8_report(devnull)
    @test r.all_ok
    # x+trₙ(x³) is a permutation for n=6 ⇒ predicate true.
    @test predicate_prop8(L_class_lut(:trace, 6), collect(0:63), 6)
end
