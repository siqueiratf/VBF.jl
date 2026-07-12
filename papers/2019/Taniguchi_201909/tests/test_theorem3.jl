@testset "theorem3_test" begin
    include(joinpath(@__DIR__, "..", "theorem3.jl"))

    # IFF check on half=4 (8-bit S-boxes, exhaustive over all 240 pairs)
    r = theorem3_verify(; half=4, m=1)
    @test r.ok
    @test r.apn_count > 0
    @test r.non_apn_count > 0

    # ≥3 CCZ-classes on F₂⁸ (3 distinct OD signatures), two of them new (a≠0).
    # Distinct signatures prove inequivalence; equal signatures would NOT prove
    # equivalence — hence a lower bound, which is how the paper argues too.
    r3 = theorem3_ccz_classes(4)
    @test r3.n_od_signatures == 3
    @test r3.ccz_classes_lower_bound == 3
    @test r3.pairwise_ccz_inequivalent     # exact are_ccz_equivalent certificate
    @test r3.n_new == 2
    @test r3.all_quadratic

    # Spot-check: (n=4, m=1, a=0, b=1) — P(x)=x³+1 has the root x=1 (1³+1=0),
    # so F is NOT APN.
    @test !projective_polynomial_rootless(4, 1, 0, 1)
    @test differential_uniformity(taniguchi_apn(4, 1, 0, 1)) > 2

    # Spot-check: (a=0, b=2) — P(x)=x³+2 is rootless in GF(2⁴), so F IS APN.
    @test projective_polynomial_rootless(4, 1, 0, 2)
    @test differential_uniformity(taniguchi_apn(4, 1, 0, 2)) == 2

    # Section-3 table — the b⁵ partition. The three mugshot buckets are exactly
    # the paper's three rows, with 20 / 30 / 120 members (170 admissible triples).
    p = theorem3_b5_partition(4)
    @test p.n_buckets == 3
    @test p.partition_exact
    @test p.kinds == [:a0, :a_nonzero_b5_eq_1, :a_nonzero_b5_ne_1]
    @test p.sizes == [20, 30, 120]
    @test p.total == 170
    # non-vacuity: no bucket straddles two rows of the paper's table
    @test !any(row -> row.kind === :mixed, p.rows)
end
