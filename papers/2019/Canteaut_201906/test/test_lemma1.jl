@testset "lemma1_test" begin
    include(joinpath(@__DIR__, "..", "lemma1.jl"))

    r3 = lemma1_build(3, 1)
    @test r3.all_zero
    @test r3.n_counterex == 0
    # α=1 has β₂=0 (not iterated), so all 7 betas valid; other 6 α skip one β₂ each
    @test r3.n_pairs == 7 + 6 * 6  # = 43

    r5 = lemma1_build(5, 1)
    @test r5.all_zero
    # α=1 has β₂=0, so 31 betas valid; other 30 α skip one β₂ each
    @test r5.n_pairs == 31 + 30 * 30  # = 931

    # i=2 spot check (gcd(2,5)=1)
    r5i2 = lemma1_build(5, 2)
    @test r5i2.all_zero
end
