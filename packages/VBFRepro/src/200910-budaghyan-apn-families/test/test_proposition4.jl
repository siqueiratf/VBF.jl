@testset "proposition4_test" begin
    include(joinpath(@__DIR__, "..", "proposition4.jl"))
    r = proposition4_report(devnull)
    @test r.all_ok
    # Even-n trace class satisfies the condition; odd-n trace class does not.
    @test satisfies_prop4(L_class_lut(:trace, 6), 6)
    @test !satisfies_prop4(L_class_lut(:trace, 5), 5)
end
