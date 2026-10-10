@testset "equivalences_test" begin
    include(joinpath(@__DIR__, "..", "equivalences.jl"))

    r3 = equivalences_build(3, 1)
    @test r3.frob_ok
    @test r3.bprime_ok
    @test r3.mirror_ok
    @test r3.n_frob == 49      # 7 α × 7 β
    @test r3.n_bprime == 42    # 6 α (α≠1) × 7 β
    # bullet 1: exponent (2^i+1)·2^t, both Frobenius forms, every t
    @test r3.expo_in_ok
    @test r3.expo_out_ok
    @test r3.n_expo == 147     # 49 pairs × 3 twists t ∈ {0,1,2}

    r5 = equivalences_build(5, 1)
    @test r5.frob_ok
    @test r5.bprime_ok
    @test r5.mirror_ok
    @test r5.expo_in_ok
    @test r5.expo_out_ok
    @test r5.n_frob == 961     # 31 α × 31 β
    @test r5.n_bprime == 930   # 30 α × 31 β
    @test r5.n_expo == 4805    # 961 pairs × 5 twists

    # i=2 spot check (gcd(2,5)=1)
    r5b = equivalences_build(5, 2)
    @test r5b.frob_ok
    @test r5b.bprime_ok
    @test r5b.mirror_ok
    @test r5b.expo_in_ok
    @test r5b.expo_out_ok

    # bullet 1 at the SBox level: the exponent-twisted butterfly has the same DU as
    # V_{α^{2^t}, β} — the *corrected* partner.
    d = exponent_du_build(3, 1)
    @test d.du_twisted_ok
    @test d.n_cases == 147
    # P2 (paper): the tex claims the partner has "the same α, β". It does not:
    # 30 of the 147 (t,α,β) have DU(V^{(t)}_{α,β}) ≠ DU(V_{α,β}), and DU is an
    # affine invariant. t=0 (the untwisted case) is of course fine.
    @test d.literal_ok_t0
    @test d.n_literal_mismatch == 30

    # single-pair identity, spelled out (α=3, β=5, t=1 at n=3, i=1)
    @test exponent_equiv_check(3, 1, 1, 3, 5) == (true, true)

    # Representation independence (R8): non-default modulus for GF(8), x³+x²+1
    r13 = equivalences_build(3, 1; modulus = 13)
    @test r13.frob_ok
    @test r13.bprime_ok
    @test r13.mirror_ok
    @test r13.expo_in_ok
    @test r13.expo_out_ok
end
