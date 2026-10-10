@testset "section 5 estimators" begin
    r = paper_estimators()
    @test abs(r.coupon_mle - 6_123_206) <= 2
    @test abs(r.overlap_estimate_rounded - 5_786_151) <= 2
    @test r.t == 92_955
    @test r.distinct == 92_253
end
