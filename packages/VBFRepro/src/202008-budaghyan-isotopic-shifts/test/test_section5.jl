@testset "section5_test" begin
    include(joinpath(@__DIR__, "..", "section5.jl"))

    results = section5_check_propositionV3()
    for r in results
        @test r.ok
    end

    # Theorem V.1 over ALL 1-term and 2-term linear L at n=6 (README R3).
    r = section5_check_theoremV1(; n = 6, i = 1)

    # Non-vacuity guards come first: without them every check below would hold
    # for free.  The scan must contain maps of each shape, so that `is_2to1` is
    # genuinely evaluated and both of its outcomes are observed.
    @test r.apn_count > 0
    @test r.n_2to1 > 0       # is_2to1 returns true somewhere ...
    @test r.n_neither > 0    # ... and false, with dim ker ≥ 2, elsewhere
    @test r.nonvacuous

    # Theorem V.1(i) on L, (ii) on M(x) = L(x)+x, and the contrapositive.
    @test r.violations_i == 0
    @test r.violations_ii == 0
    @test r.neither_but_apn == 0

    # Pin the observed structure of the scan (n=6, G_1, all 1-/2-term L):
    # 59913 maps → 890 APN shifts, every one of them with L a permutation.
    # Theorem V.1 *permits* a 2-to-1 L, but no such positive case exists in this
    # space — that branch is exercised only negatively here (README R3).
    @test r.scanned == 59913
    @test r.apn_count == 890
    @test r.apn_perm_L == 890
    @test r.apn_2to1_L == 0

    # Direct, discriminating checks of the kernel helpers themselves.
    n = 6
    mod = primitive_polynomial(n)
    L_2to1 = terms_to_lut([(1, 2), (1, 1)], n, mod)     # x² + x, kernel {0,1}
    @test kernel_size(L_2to1) == 2
    @test is_2to1(L_2to1)
    @test !is_permutation_map(L_2to1)
    L_f4 = terms_to_lut([(1, 4), (1, 1)], n, mod)       # x⁴ + x, kernel = F₄
    @test kernel_size(L_f4) == 4
    @test !is_2to1(L_f4)
    @test is_permutation_map(identity_map_lut(n))
    @test !is_2to1(identity_map_lut(n))
    @test kernel_size(identity_map_lut(n)) == 1
end
