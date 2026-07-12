@testset "lemmaB_2_test" begin
    include(joinpath(@__DIR__, "..", "lemmaB_2.jl"))

    io = IOBuffer()
    r = lemmaB_2_report(io; m_values = (3, 4))
    @test r.count_ok
    @test r.transitive_ok
    @test r.stabilizer_ok
    @test r.disjoint_ok
    @test r.all_ok
    @test length(r.rows) >= 4

    # Lemma B.1: the count is COMPUTED by enumeration and compared with the
    # formula — not asserted against itself.
    fld = BiField(3)
    rf = rootfree_biprojectives(fld, 1)
    @test length(rf) == lemma_b1_count(3) == 1176
    # sanity: the formula is not trivially the size of the whole search space
    @test length(rf) < 7 * 8 * 8 * 8

    # Lemma B.2: transitive, stabilizer 3(2^m - 1) = 21
    p0 = BiProj(1, first(rf))
    orb = g_orbit(fld, p0)
    @test length(orb) == length(rf)
    @test Set(rf) == orb
    @test g_stabilizer_size(fld, p0) == 3 * (8 - 1) == 21

    # negative control: a polynomial WITH a root is outside the orbit, so the
    # action genuinely preserves root-freeness (transitivity is not vacuous).
    rooted = BiProj(1, (1, 0, 0, 0))          # f(x,1) = x^{q+1}, root at x = 0
    @test !projective_rootfree(fld, rooted)
    @test !(rooted.c in orb)
    @test isempty(intersect(g_orbit(fld, rooted), orb))
end
