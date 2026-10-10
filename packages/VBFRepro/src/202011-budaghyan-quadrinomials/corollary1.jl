# Implements Corollary 1 from Section 3.
# Paper: Budaghyan, Helleseth, Kaleyski (2020), "A New Family of APN Quadrinomials",
#        IEEE Trans. Inf. Theory 66(11):7081–7087
# Section: 3 — Corollary 1 (tex:454-508), the F13 family of Table II
#
#   C(x) = x^3 + a·(x^(2^i+1))^(2^k) + b·x^(3·2^m) + c·(x^(2^(i+m)+2^m))^(2^k)
#
# claimed APN over GF(2^n), n = 2m, m odd, 3 ∤ m, in eight cases.
#
# Pseudocode:
#   1. Enumerate the eight (a, b, c, i, k) cases of Corollary 1 for a given n
#   2. Build each quadrinomial and compute its differential uniformity
#   3. Items 1-7 must be APN (du = 2); item 8 is a PAPER ERRATUM (du = 32)
# VBF API used: build_ci_sbox, beta_in_gfn, differential_uniformity, algebraic_degree
#
# ── PAPER ERRATUM (item 8) ───────────────────────────────────────────────────
# Item 8 claims (a,b,c) = (β,β²,1), i = n−1, k odd is APN. It is NOT: at n = 10
# we measure du = 32 for both k = 1 and k = 3.
#
# The paper contradicts itself here. Corollary 1 is derived from Theorem 2 (even
# k) and Lemma 4 (odd k). Lemma 4's list of i-values is {m+2, m, (m+2)^-1} —
# i = n−1 is NOT in it — and the prose right after Lemma 4 says outright
# (tex:446): "When k is odd, the case of i = n−1 does allow non-trivial
# solutions". Item 8 therefore has no support anywhere in the paper; it looks
# like an editing slip that carried i = n−1 over from the even-k list (item 5).
#
# We do NOT silence this: `corollary1_items` marks item 8 `apn_claimed = true`,
# `erratum = true`, and the check below asserts the measured du = 32 as evidence.

include(joinpath(@__DIR__, "helpers.jl"))
using Printf

"""
    corollary1_items(n) -> Vector{NamedTuple}

The eight cases of Corollary 1 for n = 2m, as (item, a, b, c, i, k) tuples.
`erratum = true` marks item 8, which the paper claims is APN but is not.
Item 1 is stated by the paper for n = 10 only (it is the binomial B(x)), so it
is dropped from the list for any other n.
"""
function corollary1_items(n::Int; modulus::Int = primitive_polynomial(n))
    m = n ÷ 2
    β, β² = beta_in_gfn(n; modulus)
    items = [
        (item=1, a=β, b=0,  c=0, i=3,                    k=2, note="B(x) = x^3 + β·x^36 (n=10 only)",  erratum=false),
        (item=2, a=β, b=β², c=1, i=m - 2,                k=2, note="i = m−2, k even",                  erratum=false),
        (item=3, a=β, b=β², c=1, i=invmod(m - 2, n),     k=2, note="i = (m−2)^-1, k even",             erratum=false),
        (item=4, a=β, b=β², c=1, i=m,                    k=2, note="i = m, k even",                    erratum=false),
        (item=5, a=β, b=β², c=1, i=n - 1,                k=2, note="i = n−1, k even",                  erratum=false),
        (item=6, a=β, b=β², c=1, i=mod(m + 2, n),        k=1, note="i = m+2, k odd",                   erratum=false),
        (item=7, a=β, b=β², c=1, i=invmod(m + 2, n),     k=1, note="i = (m+2)^-1, k odd",              erratum=false),
        (item=8, a=β, b=β², c=1, i=n - 1,                k=1, note="i = n−1, k odd — PAPER ERRATUM",   erratum=true),
    ]
    n == 10 ? items : filter(it -> it.item != 1, items)
end

"""
    corollary1_du(it; n, modulus) -> Int

The differential uniformity of the quadrinomial described by one Corollary 1 item.
"""
corollary1_du(it; n::Int = 10, modulus::Int = primitive_polynomial(n)) =
    differential_uniformity(
        build_ci_sbox(n, it.i, it.k; a=it.a, b=it.b, c=it.c, modulus),
    )

function corollary1_report(io::IO = stdout; n::Int = 10)
    print_section("Corollary 1: the eight claimed APN cases of family F13 (n=$n)", io)
    println(io, "  C(x) = x^3 + a(x^(2^i+1))^(2^k) + b·x^(3·2^m) + c(x^(2^(i+m)+2^m))^(2^k)")
    println(io)

    items = corollary1_items(n)
    println(io, "  item  i   k  (a,b,c)      du   claim")
    for it in items
        du = corollary1_du(it; n)
        abc = "($(it.a),$(it.b),$(it.c))"
        ok = it.erratum ? (du != 2) : (du == 2)
        print_check(
            @sprintf("%-4d  %-2d  %-1d  %-11s  %-3d  %s", it.item, it.i, it.k, abc, du, it.note),
            ok, io,
        )
    end

    print_section("Corollary 1 item 8 — PAPER ERRATUM (evidence)", io)
    println(io, "  The paper claims (a,b,c)=(β,β²,1), i=n−1, k odd is APN. It is not.")
    for k in (1, 3)
        du = corollary1_du((; a=beta_in_gfn(n)[1], b=beta_in_gfn(n)[2], c=1, i=n-1, k); n)
        print_check("n=$n, i=n−1=$(n-1), k=$k: du = $du ≠ 2, so C is NOT APN", du != 2, io)
    end
    println(io, "  Corroboration inside the paper itself:")
    println(io, "    • Lemma 4 (tex:433) lists only i ∈ {m+2, m, (m+2)^-1} for odd k — no n−1.")
    println(io, "    • tex:446: 'When k is odd, the case of i = n−1 does allow non-trivial")
    println(io, "      solutions' — i.e. the paper's own prose contradicts item 8.")

    print_section("Corollary 1 item 1 — the binomial B(x)", io)
    B = build_ci_sbox(10, 3, 2; b=0, c=0)
    du = differential_uniformity(B)
    print_check("B(x) = x^3 + β·x^36 over GF(2^10): du = $du, deg = $(algebraic_degree(B))",
                du == 2 && algebraic_degree(B) == 2, io)
    println(io, "  B(x) is the 2006 Edel–Kyureghyan–Pott binomial; the point of the paper is")
    println(io, "  that it falls out of F13 by zeroing b and c. It is the key comparison")
    println(io, "  object in Table III — see table3.jl.")
end
