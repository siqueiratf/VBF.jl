@testset "paper count arithmetic" begin
    @test table41_total() == 32_892
    r = theorem51_counts()
    @test r.lower_bound == 3_808_491
    @test r.lower_bound_matches
    @test length(TABLE_4_1_PROFILE_COUNTS) == 14
end
