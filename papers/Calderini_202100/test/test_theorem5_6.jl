@testset "theorem5_6_test" begin
    include(joinpath(@__DIR__, "..", "theorem5_6.jl"))

    # m=4 (even): F3 exists, all per-i checks pass
    r4 = theorem5_6_report(devnull; m = 4)
    @test r4.ok_f3
    @test r4.all_ok
    for rr in r4.results
        @test rr.ok_f2
        @test rr.ok_cor57_f2
        @test rr.ok_f1
        @test rr.ok_p58
    end

    # m=5 (odd): no F3 APN instance; Prop 5.8 / Cor 5.7 hold for i=1,2
    # (covers the Taniguchi identifications of Section 6.1.2, n=10)
    r5 = theorem5_6_report(devnull; m = 5)
    @test r5.ok_f3
    @test r5.all_ok
    @test length(r5.results) == 2
end
