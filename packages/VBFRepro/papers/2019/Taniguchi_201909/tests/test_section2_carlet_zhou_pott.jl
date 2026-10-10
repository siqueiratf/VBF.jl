@testset "section2_carlet_zhou_pott_test" begin
    include(joinpath(@__DIR__, "..", "section2_carlet_zhou_pott.jl"))

    # ── Corollary 2 — the a≠0 normalization branch (NOT a re-run of Theorem 1) ──
    c = carlet_cor2_verify(; n=4, i=1, j=0)
    @test c.ok
    @test c.rootless_count == 20400          # APN Theorem-1 instances at n=4, i=1, j=0
    @test c.bad_a == 0                       # every one normalizes to a' ∈ {0,1}
    @test c.bad_rootless == 0                # and G'(x,1) is still rootless
    @test c.bad_chain == 0                   # and the Φ₁/Φ₂ chain is exact at LUT level
    @test c.a1_branch == 18000               # the a'≠0 branch — Corollary 2's content
    @test c.a0_branch == 2400
    @test c.a1_branch + c.a0_branch == c.rootless_count

    # Discriminating: the Theorem-1 block's instances (u=v=0) can ONLY reach a'=0,
    # so a block that just re-ran them would never touch the a≠0 branch above.
    @test carlet_cor2_normalize(4, 1, 0, 1, 0, 0, 2).a == 0
    # …while a u≠0, v≠0 instance does reach a'=1 and lands on different parameters.
    w = c.witness
    @test w !== nothing
    @test w.u != 0 && w.v != 0
    @test w.norm.a == 1
    @test carlet_cor2_normalize(4, 1, 0, 1, 0, 0, 2).b != w.norm.b

    # The normalized function really is a quadratic APN function CCZ-equivalent to
    # the Theorem-1 function it came from.
    src = carlet_thm1_F(4, 1, 0, w.s, w.u, w.v, w.t)
    nrm = carlet_cor2_F(4, w.norm.m, w.norm.a, w.norm.b)
    @test differential_uniformity(src) == 2
    @test differential_uniformity(nrm) == 2
    @test algebraic_degree(nrm) == 2
    @test src.lut != nrm.lut                           # a genuinely different function …
    @test apn_ea_mugshot(src) == apn_ea_mugshot(nrm)   # … in the same EA/CCZ class

    # Non-vacuity of the chain identity: λ is pinned by u + t·λ^{2^i} = 0, so any
    # other λ must break the chain.
    @test carlet_cor2_chain_identity(4, 1, 0, w.s, w.u, w.v, w.t)
    @test !carlet_cor2_chain_identity(4, 1, 0, w.s, w.u, w.v, w.t; λ_override=(w.norm.λ ⊻ 1))
    @test !carlet_cor2_chain_identity(4, 1, 0, w.s, w.u, w.v, w.t; λ_override=0)

    # ── Section 2 as a whole ──────────────────────────────────────────────────
    r = section2_verify(; n=4, m=1, i_zp=2)
    @test r.ok
    @test r.carlet_ok
    @test r.zp_α == 2                # first non-cubic α in GF(2⁴)
    @test !is_cubic(2, 4)
    @test is_cubic(1, 4)
    @test r.mugshots_differ          # Zhou-Pott (i=2) ≠ Carlet Thm 1
    @test r.cor2_apn
    @test r.cor2_same_class

    # ── The paper's HEADLINE claim, on F₂⁸ ────────────────────────────────────
    # "another family of APN functions … which are not CCZ equivalent to the former
    #  two families on F₂⁸" — plus the paper's own a=0 remark, which must COLLIDE.
    h = headline_claim_verify()
    @test h.n_new == 2
    @test h.n_old == 1
    @test h.new_vs_carlet          # both a≠0 reps ≠ Carlet Thm 1   (mugshot)
    @test h.new_vs_zp              # both a≠0 reps ≠ Zhou-Pott i=2  (mugshot)
    @test h.new_vs_carlet_ccz      # …and by the exact are_ccz_equivalent oracle
    @test h.new_vs_zp_ccz
    @test h.carlet_vs_zp           # the two known families differ from each other
    # The expected collision. This is what makes the block above discriminating: a
    # broken mugshot that separated everything from everything would fail HERE.
    @test h.a0_is_zhou_pott        # Tan(a=0,b=2) == ZhouPott(i=2,α=2)
    @test h.old_is_zhou_pott
    @test h.ok
end
