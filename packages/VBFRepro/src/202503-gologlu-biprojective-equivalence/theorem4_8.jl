# Implements Theorem 4.8 — the shape theorem for equivalences of biprojective pairs.
# Paper: Göloğlu, Kölsch (2025), Electron. J. Combin.
# Section: 4.2 — A theorem to determine equivalence of projective polynomial pairs
#
#   Theorem 4.8. Assume m > 2, m ≠ 6. Let F, G be (q₁,r₁)- and (q₂,r₂)-biprojective
#   pairs, kᵢ = log₂qᵢ, lᵢ = log₂rᵢ, with k₁, l₁ ≠ m/2 and k₁ ≢ ±l₁ (mod m), and
#   assume (C): p ∤ [C_F : Z^{(q₁,r₁)}].  Then F, G are EL-equivalent iff they are
#   EL-equivalent via γ = (M 0; N L) whose eight subfunctions M₁…M₄, L₁…L₄ are
#   monomials of a common degree 2^t (or zero), and either
#     • L₂ = L₃ = 0, k₁ ≡ ±k₂, l₁ ≡ ±l₂  (mod m), or
#     • L₁ = L₄ = 0, k₁ ≡ ±l₂, l₁ ≡ ±k₂  (mod m).
#   If moreover k₁, l₁ ≢ 0 (mod m) then N = 0 (linear equivalence).
#
# This file provides the *algorithmic content* of the theorem — the restricted
# search it licenses — and then tests the theorem's own conclusion.
#
# Pseudocode (matched-exponent search, the case Theorem 5.1 actually uses):
#   1. Require k₁ ≡ k₂ and l₁ ≡ l₂ (mod m) and take L₂ = L₃ = 0.
#   2. Put Mᵢ = cᵢ^{2^t}·x^{2^t}, L₁ = d₁x^{2^t}, L₄ = d₄x^{2^t}.
#      Then, with X = c₁x + c₂y and Y = c₃x + c₄y,
#          (F ∘ M)₁ = f(X^{2^t}, Y^{2^t}) = [ (σ^{-t}f) (X, Y) ]^{2^t}
#      and (L ∘ G)₁ = d₁·g₁^{2^t} = [ σ^{-t}(d₁)·g₁ ]^{2^t},
#      so the identity holds iff, as COEFFICIENT 4-tuples,
#          compose(σ^{-t} f₁, c) = λ₁ · g₁     and     compose(σ^{-t} f₂, c) = λ₄ · g₂
#      for some λ₁, λ₄ ∈ M^×  (then dᵢ = λᵢ^{2^t}).
#   3. Scaling c ↦ a·c only rescales λ₁, λ₄, so enumerate c PROJECTIVELY:
#      1 + 2^m + 2^{2m} + 2^{3m} candidates instead of 2^{4m}.
#   4. Every hit is re-verified POINTWISE with `el_identity_holds`, so a bug in
#      the coefficient algebra cannot manufacture a false equivalence.
#
# VBF API used: apn_ea_mugshot, algebraic_degree, are_linear_equivalent (small n),
#               print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

using VBF

"""`σ^s(p)` — raise every coefficient of `p` to `2^s` (the Frobenius twist)."""
biproj_twist(fld::BiField, p::BiProj, s::Integer) =
    BiProj(p.e, ntuple(i -> frob(fld, p.c[i], s), 4))

"""
    linear_equiv_matched(F, G; collect_all = false) -> Vector

All witnesses `(t, c₁, c₂, c₃, c₄, d₁, d₄)` of a linear equivalence
`F ∘ M = L ∘ G` in the matched-exponent shape of Theorem 4.8
(`L₂ = L₃ = 0`, all subfunctions of degree `2^t`).

Requires `k_F ≡ k_G` and `l_F ≡ l_G (mod m)`; otherwise no such `γ` can exist by
the degree comparison in the proof of Theorem 4.8, and we return early.
Every candidate produced by the coefficient algebra is re-checked pointwise.
"""
function linear_equiv_matched(F::BiPair, G::BiPair; collect_all::Bool = false)
    fld = F.fld
    m = fld.m
    N = order(fld)
    out = NTuple{7,Int}[]
    mod(kexp(F), m) == mod(kexp(G), m) || return out
    mod(lexp(F), m) == mod(lexp(G), m) || return out
    for t = 0:(m-1)
        ft = biproj_twist(fld, F.f, m - t)            # σ^{-t} f₁
        gt = biproj_twist(fld, F.g, m - t)            # σ^{-t} f₂
        for c1 = 0:(N-1), c2 = 0:(N-1), c3 = 0:(N-1), c4 = 0:(N-1)
            cs = (c1, c2, c3, c4)
            idx = findfirst(!=(0), cs)                # projective normalisation
            idx === nothing && continue
            cs[idx] == 1 || continue
            (gmul(fld, c1, c4) ⊻ gmul(fld, c2, c3)) == 0 && continue     # det ≠ 0
            λ1 = proportional_scalar(fld, biproj_compose(fld, ft, c1, c2, c3, c4), G.f)
            λ1 === nothing && continue
            λ4 = proportional_scalar(fld, biproj_compose(fld, gt, c1, c2, c3, c4), G.g)
            λ4 === nothing && continue
            # lift the projective representative back to genuine witnesses
            d1 = frob(fld, λ1, t)
            d4 = frob(fld, λ4, t)
            M = BlockMap(
                MonoMap(frob(fld, c1, t), t),
                MonoMap(frob(fld, c2, t), t),
                MonoMap(frob(fld, c3, t), t),
                MonoMap(frob(fld, c4, t), t),
            )
            L = BlockMap(MonoMap(d1, t), zero_mono(), zero_mono(), MonoMap(d4, t))
            el_identity_holds(F, M, L, G) || continue          # pointwise re-check
            push!(out, (t, c1, c2, c3, c4, d1, d4))
            collect_all || return out
        end
    end
    out
end

"""Is `F` linearly equivalent to `G` in the matched-exponent shape of Thm 4.8?"""
is_linear_equiv_matched(F::BiPair, G::BiPair) = !isempty(linear_equiv_matched(F, G))

"""
    thm48_exponent_condition(F, G) -> Bool

The theorem's necessary condition on exponents:
`(k₁ ≡ ±k₂ and l₁ ≡ ±l₂)` **or** `(k₁ ≡ ±l₂ and l₁ ≡ ±k₂)` (mod m).
"""
function thm48_exponent_condition(F::BiPair, G::BiPair)
    m = F.fld.m
    pm(x, y) = mod(x - y, m) == 0 || mod(x + y, m) == 0
    k1, l1, k2, l2 = kexp(F), lexp(F), kexp(G), lexp(G)
    (pm(k1, k2) && pm(l1, l2)) || (pm(k1, l2) && pm(l1, k2))
end

"""
    thm48_hypotheses_ok(F) -> Bool

Theorem 4.8's standing hypotheses on the FIRST function: `k₁, l₁ ≠ m/2` and
`k₁ ≢ ±l₁ (mod m)`. (`m > 2, m ≠ 6` is checked separately, on the dimension.)

This is the predicate behind the theorem's `(q,m) ≠ (2,4)` exclusions: at `m = 4`
every Taniguchi / F₁ / Zhou–Pott instance has `l ≡ 2 = m/2 (mod 4)`, so the
theorem simply does not apply there — see `theorem6_1.jl`, which exhibits a
genuine CCZ-equivalence between a Zhou–Pott and an F₁ function at `m = 4`.
"""
function thm48_hypotheses_ok(F::BiPair)
    m = F.fld.m
    k = mod(kexp(F), m)
    l = mod(lexp(F), m)
    k != 0 || return false
    (iseven(m) && (k == m ÷ 2 || l == m ÷ 2)) && return false
    l != 0 || return false
    mod(k - l, m) != 0 && mod(k + l, m) != 0
end

"""
    linear_equiv_thm48(F, G; want = 1) -> Vector

Full Theorem 4.8-shaped search for `F ∘ M = L ∘ G`: every `t`, every projective
`M`-coefficient tuple, and BOTH `L`-shapes (`L₂=L₃=0` and `L₁=L₄=0`), with the
`L`-degrees the theorem dictates (`2^t` when the exponents agree, `2^{t+k}` when
they are negatives — which also swaps the two middle coefficients of the target).

Every candidate is re-verified pointwise with `el_identity_holds`, so a hit is a
*proof* of linear equivalence and a bug in the coefficient algebra can only cause
a miss, never a false positive.
"""
function linear_equiv_thm48(F::BiPair, G::BiPair; want::Int = 1)
    fld = F.fld
    m = fld.m
    N = order(fld)
    k1, l1 = mod(kexp(F), m), mod(lexp(F), m)
    k2, l2 = mod(kexp(G), m), mod(lexp(G), m)
    hits = NamedTuple[]

    # Target adjustment for one component: source exponent e1, target poly `tg`
    # with exponent e2. Returns (adjusted target, degree offset) or nothing.
    function adjust(tg::BiProj, e1::Int, e2::Int, srce::Int)
        if mod(e1 - e2, m) == 0
            return (BiProj(srce, tg.c), 0)              # L-degree 2^t
        elseif mod(e1 + e2, m) == 0
            a, b, c, d = tg.c                           # L-degree 2^{t+e1}; β ↔ γ swap
            return (BiProj(srce, (frob(fld, a, e1), frob(fld, c, e1), frob(fld, b, e1), frob(fld, d, e1))), e1)
        end
        nothing
    end

    for t = 0:(m-1)
        ft = biproj_twist(fld, F.f, m - t)
        gt = biproj_twist(fld, F.g, m - t)
        for c1 = 0:(N-1), c2 = 0:(N-1), c3 = 0:(N-1), c4 = 0:(N-1)
            cs = (c1, c2, c3, c4)
            idx = findfirst(!=(0), cs)
            idx === nothing && continue
            cs[idx] == 1 || continue
            (gmul(fld, c1, c4) ⊻ gmul(fld, c2, c3)) == 0 && continue
            P1 = biproj_compose(fld, ft, c1, c2, c3, c4)
            P2 = biproj_compose(fld, gt, c1, c2, c3, c4)
            for shape in (:diagonal, :antidiagonal)
                # :diagonal    L₂=L₃=0 → comp1 ↔ g₁ (via L₁), comp2 ↔ g₂ (via L₄)
                # :antidiagonal L₁=L₄=0 → comp1 ↔ g₂ (via L₂), comp2 ↔ g₁ (via L₃)
                tg1, e2a, tg2, e2b =
                    shape === :diagonal ? (G.f, k2, G.g, l2) : (G.g, l2, G.f, k2)
                r1 = adjust(tg1, k1, e2a, F.f.e)
                r1 === nothing && continue
                r2 = adjust(tg2, l1, e2b, F.g.e)
                r2 === nothing && continue
                λ1 = proportional_scalar(fld, P1, r1[1])
                λ1 === nothing && continue
                λ2 = proportional_scalar(fld, P2, r2[1])
                λ2 === nothing && continue
                M = BlockMap(
                    MonoMap(frob(fld, c1, t), t),
                    MonoMap(frob(fld, c2, t), t),
                    MonoMap(frob(fld, c3, t), t),
                    MonoMap(frob(fld, c4, t), t),
                )
                d1 = frob(fld, λ1, t)
                d2 = frob(fld, λ2, t)
                s1 = mod(t + r1[2], m)
                s2 = mod(t + r2[2], m)
                L =
                    shape === :diagonal ?
                    BlockMap(MonoMap(d1, s1), zero_mono(), zero_mono(), MonoMap(d2, s2)) :
                    BlockMap(zero_mono(), MonoMap(d1, s1), MonoMap(d2, s2), zero_mono())
                el_identity_holds(F, M, L, G) || continue        # pointwise proof
                push!(hits, (; shape, t, c = cs, d1, s1, d2, s2))
                length(hits) ≥ want && return hits
            end
        end
    end
    hits
end

"""
    mugshot_or_nothing(F) -> APNEAMugshot

EA-invariant fingerprint of `F` (ortho-derivative Walsh + DDT spectra for
quadratic APN). Every function here is quadratic APN, so by Theorem 4.2
(Yoshiara) CCZ-equivalence collapses to EA-equivalence and a **difference of
mugshots is a sound proof of CCZ-inequivalence**. Equality of mugshots proves
nothing — for that we always exhibit an explicit map.
"""
function mugshot_of(F::BiPair)
    S = bipair_sbox(F)
    algebraic_degree(S) == 2 ||
        error("mugshot_of: $(F.name) is not quadratic; Theorem 4.2 does not apply")
    apn_ea_mugshot(S)
end

"""
    theorem4_8_report(io = stdout; m = 5) -> NamedTuple

Test the theorem's conclusion, in both directions:

* **positive** — `F₁` at `q` and `q̄` satisfy the exponent condition, and the
  restricted search (or the paper's explicit map) really does find an
  equivalence, confirmed pointwise and by equal mugshots;
* **negative** — pairs violating the exponent condition are CCZ-inequivalent
  (distinct mugshots), so the condition is not vacuous.
"""
function theorem4_8_report(io::IO = stdout; m::Int = 5)
    print_section("Theorem 4.8 — shape of EL-equivalences between biprojective pairs", io)
    fld = BiField(m)
    p = primitive_prime_divisor(m)
    print_kv("m", m, io)
    print_kv("primitive prime divisor p of 2^m − 1 (Zsygmondy)", p, io)

    ks = [k for k = 1:(m-1) if f1_valid(fld, k)]
    Fs = [family_f1(fld, k) for k in ks]
    hyp_ok = all(thm48_hypotheses_ok, Fs)
    print_check("Theorem 4.8's standing hypotheses hold for every F₁ on M = F_2^$m", hyp_ok, io)

    # ── positive: q ↔ q̄ really is an equivalence, of the shape the theorem forces
    pos_ok = true
    pos_pairs = 0
    for F in Fs
        k = kexp(F)
        kbar = m - k
        G = family_f1(fld, kbar)
        thm48_exponent_condition(F, G) || (pos_ok = false)
        # the search reconstructs a witness of the theorem's monomial shape and
        # re-verifies it pointwise; a hit is a proof of linear equivalence.
        hits = linear_equiv_thm48(F, G)
        isempty(hits) && (pos_ok = false)
        mugshot_of(F) == mugshot_of(G) || (pos_ok = false)
        pos_pairs += 1
    end
    print_check(
        "positive: F₁(q) ≅ F₁(q̄) — a monomial-shaped witness is found and verified " *
        "pointwise ($pos_pairs pairs; mugshots agree, as they must)",
        pos_ok,
        io,
    )

    # ── negative: violating the exponent condition ⇒ CCZ-inequivalent ───────
    # F₁ alone gives no violating pair at m=5 (k₁ ≡ ±l₂ always holds for some
    # sign), so the negative control is drawn from the whole cross-family corpus.
    corpus = BiPair[]
    for k in ks
        push!(corpus, family_f1(fld, k))
        f2_valid(fld, k) && push!(corpus, family_f2(fld, k))
        isodd(m) && push!(corpus, gold_odd(fld, k))
        d = findfirst(x -> taniguchi_valid(fld, k, x), 0:(order(fld)-1))
        d === nothing || push!(corpus, taniguchi(fld, k, d - 1))
    end
    neg_total = 0
    neg_sound = 0
    for i in eachindex(corpus), j in eachindex(corpus)
        i < j || continue
        F, G = corpus[i], corpus[j]
        thm48_exponent_condition(F, G) && continue
        neg_total += 1
        mugshot_of(F) != mugshot_of(G) && (neg_sound += 1)
    end
    print_check(
        "negative: every pair violating the exponent condition is CCZ-inequivalent " *
        "($neg_sound/$neg_total, via distinct ortho-derivative mugshots)",
        neg_total > 0 && neg_sound == neg_total,
        io,
    )

    # ── the restricted search never contradicts the invariant ──────────────
    search_ok = true
    found = 0
    for i in eachindex(Fs), j in eachindex(Fs)
        F, G = Fs[i], Fs[j]
        mod(kexp(F), m) == mod(kexp(G), m) || continue     # matched-exponent case only
        hit = is_linear_equiv_matched(F, G)
        same = mugshot_of(F) == mugshot_of(G)
        hit && (found += 1)
        # a hit is a *proof* of equivalence (pointwise-checked), so it must not
        # contradict the invariant
        hit && !same && (search_ok = false)
    end
    print_check(
        "matched-exponent search: every hit is pointwise-verified and consistent " *
        "with the mugshot invariant ($found hits)",
        search_ok && found > 0,
        io,
    )
    println(
        io,
        "  [NOTE] Theorem 4.8 requires m ≠ 6; at m = 6 no primitive prime divisor of",
    )
    println(
        io,
        "         2⁶−1 = 63 exists (Zsygmondy exception), so P and the Sylow argument",
    )
    println(io, "         collapse. primitive_prime_divisor(6) = $(primitive_prime_divisor(6)).")
    print_kv("completeness", "exhaustive over the F₁ instances on M = F_2^$m", io)

    (;
        m = m,
        p = p,
        hypotheses_ok = hyp_ok,
        positive_pairs = pos_pairs,
        positive_ok = pos_ok,
        negative_total = neg_total,
        negative_sound = neg_sound,
        search_hits = found,
        all_ok = hyp_ok &&
                 pos_ok &&
                 neg_total > 0 &&
                 neg_sound == neg_total &&
                 search_ok &&
                 found > 0,
    )
end
