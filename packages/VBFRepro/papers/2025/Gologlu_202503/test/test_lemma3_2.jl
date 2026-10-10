@testset "lemma3_2_test" begin
    include(joinpath(@__DIR__, "..", "lemma3_2.jl"))

    io = IOBuffer()
    r = lemma3_2_report(io; max_m = 14)
    @test isempty(r.failures)
    @test r.admissible_checked > 0
    @test r.negative_controls > 0          # the negative half is non-empty
    @test r.all_ok

    # positive: the six values are exactly (3,3,3,1,1,1) for an admissible (m,k)
    g = lemma3_2_gcds(6, 1)
    @test (g.gcd_qp1, g.gcd_rm1, g.gcd_q2m1) == (3, 3, 3)
    @test (g.gcd_qm1, g.gcd_rp1, g.gcd_qp1_Qm1) == (1, 1, 1)
    @test g.gcd_kQ_m == 2                  # gcd(k + m/2, m) = 2, used in the proof
    @test lemma3_2_holds(6, 1)
    @test lemma3_2_holds(10, 3)

    # negative: gcd(k,m) ≠ 1 breaks the identities — so the hypothesis is real
    @test !lemma3_2_holds(6, 2)
    @test !lemma3_2_holds(6, 3)
    @test !lemma3_2_holds(10, 5)
end
