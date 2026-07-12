# Implements Section 2 — known examples (+ the paper's headline novelty claim)
# Paper: Taniguchi (2019), "On some quadratic APN functions"
# Section: 2 — Known examples and their Γ-ranks in F_{2^8}
#
# Pseudocode:
#   Carlet Theorem 1:
#     G(x,y) = s·x^{2^i+2^j} + u·x^{2^i}y^{2^j} + v·x^{2^j}y^{2^i} + t·y^{2^i+2^j}
#     F(x,y)=(xy,G(x,y)) is APN ⟺ G(x,1) has no root in GF(2ⁿ)
#   Corollary 2 (normalization of Theorem 1), m = i-j:
#     1. coordinate change (x,y) ↦ (x, λx+y) with λ = (u/t)^{2^{-i}} kills u:
#          F(x,λx+y) = (xy + λx², G₁(x,y)),  G₁ = s'x^{2^i+2^j}+v'x^{2^j}y^{2^i}+t·y^{2^i+2^j}
#     2. Φ₁ : (u,v) ↦ (u, (v/s')^{2^{-j}})   ⟹   G₂ = x^{2^m+1} + a·x·y^{2^m} + b·y^{2^m+1}
#     3. if a ≠ 0: coordinate change (x,y) ↦ (c·x, y) with c = a^{2^{-m}}, then
#        Φ₂ : (u,v) ↦ (u/c, v/(a·c))         ⟹   G' = x^{2^m+1} + 1·x·y^{2^m} + b'·y^{2^m+1}
#     so a' ∈ {0,1}, and G'(x,1) = x^{2^m+1}+a'x+b' is still rootless.
#     Every step is affine/linear (the λx² term is GF(2)-linear ⇒ Lemma 1), hence CCZ.
#   Zhou-Pott Corollary 1 (i=2):
#     G(x,y) = x^{2^m+1} + α·y^{(2^m+1)·2^i}, i even, α non-cubic
#   Headline claim (abstract): on F₂⁸ the two a≠0 Taniguchi classes are CCZ-inequivalent
#     to BOTH former families; and Taniguchi's a=0 member falls back into Zhou-Pott.
#
# VBF API used: gf_pow, gf_mul, gf_inv, primitive_polynomial, differential_uniformity,
#               algebraic_degree, apn_ea_mugshot, are_ccz_equivalent, taniguchi_apn,
#               taniguchi_apn_representatives, SBox

using VBF
include(joinpath(@__DIR__, "helpers.jl"))

# ── Carlet Theorem 1 construction ─────────────────────────────────────────────

"""
    carlet_thm1_G(n, i, j, s, u, v, t, x, y) -> Int

Carlet's `G(x,y) = s·x^{2^i+2^j} + u·x^{2^i}y^{2^j} + v·x^{2^j}y^{2^i} + t·y^{2^i+2^j}`
at a single point, over GF(2ⁿ).
"""
function carlet_thm1_G(n::Int, i::Int, j::Int, s::Int, u::Int, v::Int, t::Int, x::Int, y::Int)
    md = primitive_polynomial(n)
    M(p, q) = gf_mul(p, q, n; modulus=md)
    P(p, e) = gf_pow(p, e, n; modulus=md)
    E1 = (1 << i) + (1 << j)
    M(s, P(x, E1)) ⊻
    M(u, M(P(x, 1 << i), P(y, 1 << j))) ⊻
    M(v, M(P(x, 1 << j), P(y, 1 << i))) ⊻
    M(t, P(y, E1))
end

"""
    carlet_thm1_F(n, i, j, s, u, v, t) -> SBox{2n}

Carlet's Theorem 1: F(x,y)=(xy,G(x,y)) over GF(2ⁿ)×GF(2ⁿ), packed as SBox{2n}.
Requires s≠0, t≠0, gcd(n,i-j)=1.
"""
function carlet_thm1_F(n::Int, i::Int, j::Int, s::Int, u::Int, v::Int, t::Int)
    md = primitive_polynomial(n)
    lut = Vector{Int}(undef, 1 << (2n))
    for x = 0:(1<<n)-1, y = 0:(1<<n)-1
        lut[(x | (y << n)) + 1] =
            gf_mul(x, y, n; modulus=md) | (carlet_thm1_G(n, i, j, s, u, v, t, x, y) << n)
    end
    SBox{2n}(lut)
end

# ── Corollary 2: the normalized (a' ∈ {0,1}) form ─────────────────────────────

"""
    carlet_cor2_G(n, m, a, b, x, y) -> Int

The normalized `G'(x,y) = x^{2^m+1} + a·x·y^{2^m} + b·y^{2^m+1}` at a single point.
"""
function carlet_cor2_G(n::Int, m::Int, a::Int, b::Int, x::Int, y::Int)
    md = primitive_polynomial(n)
    M(p, q) = gf_mul(p, q, n; modulus=md)
    P(p, e) = gf_pow(p, e, n; modulus=md)
    P(x, (1 << m) + 1) ⊻ M(a, M(x, P(y, 1 << m))) ⊻ M(b, P(y, (1 << m) + 1))
end

"""
    carlet_cor2_F(n, m, a, b) -> SBox{2n}

Corollary 2's normalized APN function F'(x,y) = (xy, G'(x,y)) with
G'(x,y) = x^{2^m+1} + a·x·y^{2^m} + b·y^{2^m+1} and a ∈ {0,1}. APN iff
G'(x,1) = x^{2^m+1}+a·x+b has no root in GF(2ⁿ).
"""
function carlet_cor2_F(n::Int, m::Int, a::Int, b::Int)
    md = primitive_polynomial(n)
    lut = Vector{Int}(undef, 1 << (2n))
    for x = 0:(1<<n)-1, y = 0:(1<<n)-1
        lut[(x | (y << n)) + 1] =
            gf_mul(x, y, n; modulus=md) | (carlet_cor2_G(n, m, a, b, x, y) << n)
    end
    SBox{2n}(lut)
end

"""
    carlet_cor2_normalize(n, i, j, s, u, v, t) -> NamedTuple

Run the proof of Corollary 2 as an algorithm: from a Theorem-1 instance
(i, j, s, u, v, t) produce the normalized parameters (m, a, b) with **a ∈ {0,1}**,
together with the coefficients of the coordinate changes that get you there
(`λ`, `s′`, `c`, `d`) so that the transformation chain itself can be checked at the
LUT level by [`carlet_cor2_chain_identity`](@ref).

Requires s≠0, t≠0, i>j≥0. When `G(x,1)` is rootless (the APN case) `s′ ≠ 0` is
automatic: by homogeneity `s′ = G(1,λ)` and `G(1,λ) = 0` would force the root
`x = 1/λ` of `G(x,1)`.
"""
function carlet_cor2_normalize(n::Int, i::Int, j::Int, s::Int, u::Int, v::Int, t::Int)
    md = primitive_polynomial(n)
    i > j >= 0 || error("need i > j ≥ 0, got i=$i j=$j")
    s != 0 && t != 0 || error("Carlet Theorem 1 needs s≠0 and t≠0")
    M(p, q) = gf_mul(p, q, n; modulus=md)
    F(x, k) = gf_pow(x, 1 << mod(k, n), n; modulus=md)   # x ↦ x^{2^k}, k ∈ ℤ
    IV(x) = gf_inv(x, n; modulus=md)
    m = i - j

    # (1) (x,y) ↦ (x, λx+y) kills u:  u_new = u + t·λ^{2^i} = 0  ⟺  λ = (u/t)^{2^{-i}}
    λ = F(M(u, IV(t)), -i)
    s′ = s ⊻ M(u, F(λ, j)) ⊻ M(v, F(λ, i)) ⊻ M(t, M(F(λ, i), F(λ, j)))
    v′ = v ⊻ M(t, F(λ, j))
    s′ != 0 || error("s′ = 0 — G(x,1) had a root, instance is not APN")

    # (2) Φ₁ : (u,v) ↦ (u, (v/s′)^{2^{-j}})
    a = F(M(v′, IV(s′)), -j)
    b = F(M(t, IV(s′)), -j)
    a == 0 && return (; m, a=0, b, λ, s′, c=1, d=1)

    # (3) (x,y) ↦ (c·x, y) with c = a^{2^{-m}}, then Φ₂ : (u,v) ↦ (u/c, v/d), d = a·c
    c = F(a, -m)
    d = M(a, c)
    (; m, a=1, b=M(b, IV(d)), λ, s′, c, d)
end

"""
    carlet_cor2_chain_identity(n, i, j, s, u, v, t; λ_override=nothing) -> Bool

Exact LUT check of Corollary 2's transformation chain: with (m,a,b,λ,s′,c,d) from
[`carlet_cor2_normalize`](@ref), for every (x,y) ∈ GF(2ⁿ)²

    Φ₂( Φ₁( F(c·x, λ·c·x + y) ) )  ==  ( x·y + (λ·c)·x² ,  G'(x,y) )

i.e. the input coordinate changes and the output maps Φ₁, Φ₂ really do carry the
Theorem-1 function onto `(xy + λ'x², G')`. The residual `λ'x²` term is GF(2)-linear,
so Lemma 1 gives CCZ-equivalence with `F'(x,y) = (xy, G'(x,y))` — which is exactly
what Corollary 2 asserts.

`λ_override` substitutes a different λ into the chain; it exists so the tests can
feed in a *wrong* λ and watch the identity fail. λ is pinned by `u + t·λ^{2^i} = 0`,
so any other value must break the chain — an identity that survived an arbitrary λ
would not be testing anything.
"""
function carlet_cor2_chain_identity(
    n::Int,
    i::Int,
    j::Int,
    s::Int,
    u::Int,
    v::Int,
    t::Int;
    λ_override::Union{Nothing,Int} = nothing,
)
    md = primitive_polynomial(n)
    M(p, q) = gf_mul(p, q, n; modulus=md)
    F(x, k) = gf_pow(x, 1 << mod(k, n), n; modulus=md)
    IV(x) = gf_inv(x, n; modulus=md)
    r = carlet_cor2_normalize(n, i, j, s, u, v, t)
    λ = λ_override === nothing ? r.λ : λ_override
    for x = 0:(1<<n)-1, y = 0:(1<<n)-1
        X = M(r.c, x)                                    # (x,y) ↦ (c·x, y) …
        Y = M(λ, X) ⊻ y                                  # … then (x,y) ↦ (x, λx+y)
        U = M(X, Y)                                      # first  coordinate of F
        V = carlet_thm1_G(n, i, j, s, u, v, t, X, Y)     # second coordinate of F
        U′ = M(U, IV(r.c))                               # Φ₂ on u
        V′ = M(F(M(V, IV(r.s′)), -j), IV(r.d))           # Φ₁ then Φ₂ on v
        U′ == M(x, y) ⊻ M(M(λ, r.c), M(x, x)) || return false
        V′ == carlet_cor2_G(n, r.m, r.a, r.b, x, y) || return false
    end
    true
end

# ── Zhou-Pott Corollary 1 ─────────────────────────────────────────────────────

"""
    zhou_pott_cor1_F(n, m, i, α) -> SBox{2n}

Zhou-Pott Corollary 1: G(x,y)=x^{2^m+1}+α·y^{(2^m+1)·2^i}, F(x,y)=(xy,G(x,y)).
APN when n even, gcd(m,n)=1, i even >0, α non-cubic (α≠t³ for all t∈GF(2ⁿ)).
"""
function zhou_pott_cor1_F(n::Int, m::Int, i::Int, α::Int)
    md = primitive_polynomial(n)
    Em = (1 << m) + 1
    Ey = Em * (1 << i)
    lut = Vector{Int}(undef, 1 << (2n))
    for x = 0:(1<<n)-1, y = 0:(1<<n)-1
        Gxy = gf_pow(x, Em, n; modulus=md) ⊻
              gf_mul(α, gf_pow(y, Ey, n; modulus=md), n; modulus=md)
        lut[(x | (y << n)) + 1] = gf_mul(x, y, n; modulus=md) | (Gxy << n)
    end
    SBox{2n}(lut)
end

"""
    is_cubic(α, n) -> Bool

True iff α = t³ for some t∈GF(2ⁿ).
"""
function is_cubic(α::Int, n::Int)
    md = primitive_polynomial(n)
    any(gf_pow(x, 3, n; modulus=md) == α for x = 1:(1<<n)-1)
end

# ── Verification ──────────────────────────────────────────────────────────────

"""
    carlet_cor2_verify(; n, i, j) -> NamedTuple

Corollary 2, exhaustively: for **every** Theorem-1 instance (s,u,v,t) with s,t≠0
whose `G(x,1)` is rootless (i.e. every APN one), normalize it and check that

  1. the normalized `a` really lands in {0,1};
  2. the normalized `G'(x,1) = x^{2^m+1}+a·x+b` is **still rootless** — this is the
     load-bearing claim ("by assumption on G(x,1)") and the thing a copy of the
     Theorem-1 block cannot possibly test;
  3. the coordinate-change chain reproduces `(xy + λ'x², G'(x,y))` exactly, at the
     LUT level ([`carlet_cor2_chain_identity`](@ref)).

Reports how many instances hit the `a=0` branch and how many hit the `a≠0` branch —
the `a≠0` branch is Corollary 2's whole content, and the Theorem-1 block's
(u=v=0) instances only ever reach `a=0`.
"""
function carlet_cor2_verify(; n::Int=4, i::Int=1, j::Int=0)
    rootless_count = 0
    a0 = 0
    a1 = 0
    bad_a = 0
    bad_rootless = 0
    bad_chain = 0
    witness = nothing            # an instance with u≠0, v≠0 that reaches the a≠0 branch
    for s = 1:(1<<n)-1, u = 0:(1<<n)-1, v = 0:(1<<n)-1, t = 1:(1<<n)-1
        carlet_G1_rootless(n, i, j, s, u, v, t) || continue
        rootless_count += 1
        r = carlet_cor2_normalize(n, i, j, s, u, v, t)
        r.a in (0, 1) || (bad_a += 1)
        projective_polynomial_rootless(n, r.m, r.a, r.b) || (bad_rootless += 1)
        carlet_cor2_chain_identity(n, i, j, s, u, v, t) || (bad_chain += 1)
        if r.a == 1
            a1 += 1
            (witness === nothing && u != 0 && v != 0) && (witness = (; s, u, v, t, norm=r))
        else
            a0 += 1
        end
    end
    (; ok=(bad_a == 0 && bad_rootless == 0 && bad_chain == 0 && a1 > 0),
       rootless_count, a0_branch=a0, a1_branch=a1,
       bad_a, bad_rootless, bad_chain, witness)
end

"""
    section2_verify(; n, m, i_zp) -> NamedTuple

Verify Section 2 for half-dimension n, Frobenius index m, Zhou-Pott shift i_zp:
  - Carlet Thm 1: APN ⟺ G(x,1) rootless (exhaustive in t at s=1, u=v=0)
  - Corollary 2: the a≠0 normalization branch (see [`carlet_cor2_verify`](@ref))
  - Zhou-Pott Cor 1 (i=i_zp): APN for the first non-cubic α
  - Zhou-Pott (i=i_zp) is EA-inequivalent to Carlet
"""
function section2_verify(; n::Int=4, m::Int=1, i_zp::Int=2)
    gcd(m, n) == 1 || error("need gcd(m,n)=1")
    iseven(n)       || error("need n even for Zhou-Pott Cor 1")
    iseven(i_zp) && i_zp > 0 || error("need i_zp even and >0")

    # Carlet Thm 1: s=1, u=v=0, i=m, j=0 — check the IFF in t and keep a rootless one
    i_c, j_c = m, 0
    carlet_ok = false
    carlet_F = nothing
    carlet_t = nothing
    for t = 1:(1<<n)-1
        rootless = carlet_G1_rootless(n, i_c, j_c, 1, 0, 0, t)
        F = carlet_thm1_F(n, i_c, j_c, 1, 0, 0, t)
        is_apn = differential_uniformity(F) == 2
        rootless == is_apn || return (; ok=false, msg="Carlet Thm1 IFF failed at t=$t")
        if rootless && !carlet_ok
            carlet_ok = true
            carlet_F = F
            carlet_t = t
        end
    end
    carlet_ok || return (; ok=false, msg="no rootless Carlet instance found")

    # Corollary 2 — the a≠0 branch, exhaustively over all Theorem-1 instances
    cor2 = carlet_cor2_verify(; n, i=i_c, j=j_c)
    cor2.ok || return (; ok=false, msg="Corollary 2 normalization failed: $cor2")
    w = cor2.witness
    cor2_F = carlet_cor2_F(n, w.norm.m, w.norm.a, w.norm.b)
    cor2_apn = differential_uniformity(cor2_F) == 2 && algebraic_degree(cor2_F) == 2
    # CCZ-invariant cross-check of the normalization on the witness
    src_F = carlet_thm1_F(n, i_c, j_c, w.s, w.u, w.v, w.t)
    cor2_same_class = apn_ea_mugshot(src_F) == apn_ea_mugshot(cor2_F)

    # Zhou-Pott Cor 1 (i=i_zp): first non-cubic α
    zp_F = nothing
    zp_α = nothing
    for α = 1:(1<<n)-1
        is_cubic(α, n) && continue
        F = zhou_pott_cor1_F(n, m, i_zp, α)
        if differential_uniformity(F) == 2
            zp_F = F
            zp_α = α
            break
        end
    end
    zp_F !== nothing || return (; ok=false, msg="no valid Zhou-Pott Cor1 instance found")

    mugshots_differ = apn_ea_mugshot(carlet_F) != apn_ea_mugshot(zp_F)

    (; ok=(mugshots_differ && cor2_apn && cor2_same_class),
       carlet_ok, carlet_t, carlet_F,
       cor2, cor2_F, cor2_apn, cor2_same_class,
       cor2_a=w.norm.a, cor2_b=w.norm.b, cor2_m=w.norm.m,
       cor2_source=(w.s, w.u, w.v, w.t),
       zp_α, zp_F, mugshots_differ,
       msg=mugshots_differ ? "Zhou-Pott (i=$i_zp) and Carlet are EA-inequivalent" :
                             "UNEXPECTED: mugshots equal — should differ")
end

"""
    headline_claim_verify() -> NamedTuple

The paper's abstract: *"we propose another family of APN functions … which are not
CCZ equivalent to the former two families on F₂⁸"*.

On F₂⁸ (half = 4) compare, by `apn_ea_mugshot` (an ortho-derivative EA/CCZ-invariant
that is complete enough to separate these classes) and by the exact
`are_ccz_equivalent` oracle:

  - the two **new** Taniguchi reps (a≠0) vs a Carlet Theorem-1 rep  → must differ
  - the two **new** Taniguchi reps (a≠0) vs a Zhou-Pott Cor-1 (i=2) rep → must differ
  - Taniguchi (a=0, b=2) vs Zhou-Pott (i=2, α=2) → must be **equal**: the paper's own
    remark *"if a = 0, then F(x,y) in Theorem 3 belongs to the family of Theorem 2"*.

The a=0 collision is what makes this test discriminating: a check that merely said
"everything differs from everything" would pass on a broken mugshot too.
"""
function headline_claim_verify()
    n = 4                                   # F₂⁸ = GF(2⁴) × GF(2⁴)
    carlet = carlet_thm1_F(n, 1, 0, 1, 0, 0, 2)      # x^3 + 2·y^3 ; G(x,1)=x³+2 rootless
    zp = zhou_pott_cor1_F(n, 1, 2, 2)                # x^3 + 2·y^{12} ; α=2 non-cubic, i=2
    reps = taniguchi_apn_representatives(n)
    new_reps = filter(r -> r.new, reps)
    old_reps = filter(r -> !r.new, reps)

    mg_c = apn_ea_mugshot(carlet)
    mg_z = apn_ea_mugshot(zp)

    new_vs_carlet = all(apn_ea_mugshot(r.sbox) != mg_c for r in new_reps)
    new_vs_zp = all(apn_ea_mugshot(r.sbox) != mg_z for r in new_reps)
    carlet_vs_zp = mg_c != mg_z
    # exact CCZ oracle on the same pairs (quadratic APN ⇒ CCZ = EA, complete decision)
    new_vs_carlet_ccz = all(!are_ccz_equivalent(r.sbox, carlet) for r in new_reps)
    new_vs_zp_ccz = all(!are_ccz_equivalent(r.sbox, zp) for r in new_reps)

    # the paper's a=0 remark — the expected *collision*
    tan_a0 = taniguchi_apn(n, 1, 0, 2)
    a0_is_zhou_pott = apn_ea_mugshot(tan_a0) == mg_z
    old_is_zhou_pott = all(apn_ea_mugshot(r.sbox) == mg_z for r in old_reps)

    (; ok=(new_vs_carlet && new_vs_zp && carlet_vs_zp && new_vs_carlet_ccz &&
           new_vs_zp_ccz && a0_is_zhou_pott && old_is_zhou_pott),
       n_new=length(new_reps), n_old=length(old_reps),
       new_vs_carlet, new_vs_zp, carlet_vs_zp,
       new_vs_carlet_ccz, new_vs_zp_ccz,
       a0_is_zhou_pott, old_is_zhou_pott,
       new_params=[(r.m, r.a, r.b) for r in new_reps])
end

function section2_carlet_zhou_pott_report(io::IO = stdout)
    print_section(io, "Section 2 — Carlet Theorem 1 + Zhou-Pott Corollary 1")

    r = section2_verify(; n=4, m=1, i_zp=2)
    print_check(io, "n=4 m=1: Carlet Thm1 APN iff G(x,1) rootless (all t)", r.carlet_ok)
    print_check(io, "n=4 m=1: Zhou-Pott Cor1 (i=2) APN for non-cubic α=$(r.zp_α)", r.zp_α !== nothing)
    print_check(io, "n=4 m=1: Zhou-Pott (i=2) EA-inequivalent to Carlet Thm1", r.mugshots_differ)
    print_kv(io, "Γ-rank Carlet (F₂⁸)", "13200  [loaded from paper — Magma, out-of-scope]")
    print_kv(io, "Γ-rank Zhou-Pott i=2 (F₂⁸)", "13642  [loaded from paper — Magma, out-of-scope]")

    print_section(io, "Corollary 2 — normalization of Theorem 1 to a' ∈ {0,1}")
    c = r.cor2
    print_check(io, "n=4: all $(c.rootless_count) APN Theorem-1 instances normalize to a' ∈ {0,1}",
                c.bad_a == 0)
    print_check(io, "n=4: the normalized G'(x,1)=x^{2^m+1}+a'x+b' stays rootless (all $(c.rootless_count))",
                c.bad_rootless == 0)
    print_check(io, "n=4: the (x,y)↦(cx, λcx+y) / Φ₁ / Φ₂ chain reproduces (xy+λ'x², G') exactly",
                c.bad_chain == 0)
    print_check(io, "n=4: the a≠0 branch is actually exercised ($(c.a1_branch) instances)",
                c.a1_branch > 0)
    print_check(io, "n=4: normalized F'=(xy,G') is a quadratic APN function", r.cor2_apn)
    print_check(io, "n=4: F (Thm 1) and F' (Cor 2) lie in one EA-class (equal mugshot)",
                r.cor2_same_class)
    print_kv(io, "branch split", "$(c.a1_branch) instances reach a'=1, $(c.a0_branch) reach a'=0")
    print_kv(io, "witness (s,u,v,t)", "$(r.cor2_source) → (m=$(r.cor2_m), a'=$(r.cor2_a), b'=$(r.cor2_b))")
    println(io, "  note: the Theorem-1 block above uses u=v=0, which can only ever reach")
    println(io, "  a'=0; the a'=1 branch is Corollary 2's entire content.")

    print_section(io, "Headline claim (abstract) — the new classes are new on F₂⁸")
    h = headline_claim_verify()
    print_check(io, "F₂⁸: both new Taniguchi reps (a≠0) ≠ Carlet Thm1 (mugshot)", h.new_vs_carlet)
    print_check(io, "F₂⁸: both new Taniguchi reps (a≠0) ≠ Zhou-Pott Cor1 i=2 (mugshot)", h.new_vs_zp)
    print_check(io, "F₂⁸: both new Taniguchi reps (a≠0) ≠ Carlet Thm1 (are_ccz_equivalent)",
                h.new_vs_carlet_ccz)
    print_check(io, "F₂⁸: both new Taniguchi reps (a≠0) ≠ Zhou-Pott Cor1 i=2 (are_ccz_equivalent)",
                h.new_vs_zp_ccz)
    print_check(io, "F₂⁸: Carlet Thm1 ≠ Zhou-Pott Cor1 i=2", h.carlet_vs_zp)
    print_check(io, "F₂⁸: Taniguchi(a=0,b=2) == Zhou-Pott(i=2,α=2) — the paper's a=0 remark",
                h.a0_is_zhou_pott)
    print_check(io, "F₂⁸: every a=0 Taniguchi rep is a Zhou-Pott (i=2) function",
                h.old_is_zhou_pott)
    print_kv(io, "new reps (m,a,b)", string(h.new_params))
    println(io, "  completeness: Corollary 2 exhaustive over all Theorem-1 instances at n=4;")
    println(io, "  headline claim on F₂⁸; Γ-ranks not recomputed (Magma-only, n=8 guard)")
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    section2_carlet_zhou_pott_report()
end
