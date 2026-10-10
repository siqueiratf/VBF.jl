@testset "Eight-bit profile-order evidence" begin
    F = gold_apn(8, 1)
    r = table41_member_profiles(F; depth=2, max_nodes=1_000_000)
    @test all(row.status == :complete for row in values(r.results))
    @test all(length(row.profile) == 3 for row in values(r.results))
    @test r.results[:lex].profile[1] == (0, 0)
    stopped = table41_member_profiles(F; depth=5, max_nodes=0)
    @test all(row.status == :inconclusive for row in values(stopped.results))
    @test all(!hasproperty(row, :profile) for row in values(stopped.results))
    @test_throws ArgumentError table41_member_profiles(SBox{8}(zeros(UInt8, 256)))
end
