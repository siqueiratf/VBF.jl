@testset "definition1_test" begin
    include(joinpath(@__DIR__, "..", "definition1.jl"))

    # n=3, i=1: the full 49-pair sweep. Non-vacuous — 6 of the 49 are APN.
    r = definition1_build(3, 1)
    @test r.n_pairs == 49                  # 7 α × 7 β
    @test r.all_perm                       # tex: H_R is a permutation
    @test r.all_involution                 # tex: H_R is an involution
    @test r.all_du_match                   # DU(H_R) = DU(V_R): H_R is CCZ-equiv to V_R
    @test r.n_apn == 6                     # same 6 APN pairs the closed butterfly has
    @test r.apn_deg_ok                     # deg(H_R) = n+1 = 4 on every APN pair
    @test r.apn_ccz_ok                     # are_ccz_equivalent(H_R, V_R) on every APN pair
    @test r.beta1_deg_ok                   # deg = n+1 for the β=1 subfamily, α≠0,1

    # The degree claim is scoped, not universal: for general β the degree of H_R
    # does drop to n for some pairs (so `beta1_deg_ok` is a real constraint and
    # `deg_np1_count == n_pairs` would be false).
    @test r.deg_np1_count == 36
    @test r.deg_np1_count < r.n_pairs

    # n=3, i=2 (the other gcd(i,3)=1 exponent)
    r2 = definition1_build(3, 2)
    @test r2.all_perm && r2.all_involution && r2.all_du_match
    @test r2.n_apn == 6
    @test r2.apn_deg_ok && r2.apn_ccz_ok && r2.beta1_deg_ok

    # n=5, β=1 slice: the construction generalises; degree is n+1 = 6; no APN pair.
    r5 = definition1_build(5, 1; pairs = [(a, 1) for a in 1:31], check_ccz = false)
    @test r5.n_pairs == 31
    @test r5.all_perm && r5.all_involution && r5.all_du_match
    @test r5.beta1_deg_ok
    @test r5.n_apn == 0

    # Representation independence (R8): non-default modulus for GF(8), x³+x²+1.
    # Every Definition 1 property survives the change of basis; only the α values permute.
    r13 = definition1_build(3, 1; modulus = 13)
    @test r13.all_perm && r13.all_involution && r13.all_du_match
    @test r13.n_apn == 6
    @test r13.apn_deg_ok && r13.apn_ccz_ok && r13.beta1_deg_ok
    @test r13.deg_np1_count == 36

    # H_R against the paper's own worked example: V_{α=2,β=1} (n=3,i=1) is APN,
    # so H_R is an APN *permutation* on 6 bits — the object the paper is about.
    H = butterfly_open_lut(3, 1, 2, 1)
    V = butterfly_closed_lut(3, 1, 2, 1)
    @test is_permutation(H)
    @test !is_permutation(V)               # the closed butterfly is not a permutation
    @test differential_uniformity(H) == 2
    @test algebraic_degree(H) == 4         # n+1
    @test are_ccz_equivalent(H, V)

    # Guard (R5): the paper's hypothesis is n odd, gcd(i,n)=1
    @test_throws AssertionError butterfly_open_lut(4, 1, 2, 1)
end
