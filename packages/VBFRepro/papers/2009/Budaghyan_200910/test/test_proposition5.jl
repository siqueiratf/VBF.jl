@testset "proposition5_test" begin
    include(joinpath(@__DIR__, "..", "proposition5.jl"))
    r = proposition5_report(devnull)
    @test r.all_ok
    # Predicate holds for the trace permutation, fails for identity (x+x³ not perm).
    @test predicate_prop5(L_class_lut(:trace, 6), 6)
    @test !predicate_prop5(collect(0:63), 6)
end
