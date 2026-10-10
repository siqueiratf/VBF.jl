# Implements Section 4 — F is highly nonlinear.
# Paper: Bracken, Tan, Tan (2012), "Binomial differentially 4 uniform permutations
#        with high nonlinearity", Finite Fields Appl. 18 (2012) 537–546
# Section: 4 — F is highly nonlinear (Lemma 4.1, Lemma 4.2, Theorem 1.1)
#
# Pseudocode:
#   1. Lemma 4.1: a linearised polynomial Σ_{i=0..d} r_i x^{2^{si}} with
#      gcd(n,s)=1 has at most 2^d roots — randomised check with `trials`
#   2. Build F = bracken_binomial_sbox(k, s); collect the SIGNED Walsh value set
#   3. Lemma 4.2: |F^W(a,b)| ≤ 2^{(n+t)/2} (n+t even) / 2^{(n+t-1)/2} (n+t odd),
#      but only for F as defined in Theorem 1.2, i.e. only when k/t is ODD
#   4. Theorem 1.1 (t = 2): the Walsh spectrum is a SUBSET of
#      {0, ±2^{n/2}, ±2^{(n+2)/2}} — a value-set claim a bound cannot certify
# VBF API used: SBox, lat, linearity, nonlinearity, absolute_walsh_spectrum,
#               walsh_hadamard!, gf_mul, gf_pow
#
# Runtime measured on this machine with @elapsed (Julia 1.12.6, AMD Ryzen 5
# 5600G, single-threaded).  ONE figure per size, used everywhere (BTT-9):
#   n=15 streaming Walsh value set : 4.9 s per instance
#   n=15 linearity_rowwise         : same scan, 4.9 s (it is the peak of the set)
#   n=12 core lat + value set      : 0.6 s per instance
# Default grid (9 instances) ≈ 13 s; `full_search = true` adds three redundant
# t=1 instances at n=15 for ~15 s more.

include(joinpath(@__DIR__, "helpers.jl"))

# (k, s, expected signed Walsh value set, heavy?)
# Every entry was measured here; `heavy = true` marks the three n=15 instances
# that merely repeat (5,1)'s t=1 shape, so they run only under `full_search`.
const SECTION4_CASES = [
    (1, 2, [-4, 0, 4], false),                 # n=3,  t=1, k/t=1 odd
    (2, 1, [-16, -8, 0, 8, 16], false),        # n=6,  t=1, k/t=2 even
    (2, 4, [-16, 0, 16], false),               # n=6,  t=2, k/t=1 odd  ← Theorem 1.1
    (4, 2, [-256, -64, 0, 64, 256], false),    # n=12, t=2, k/t=2 even
    (4, 5, [-128, -64, 0, 64, 128], false),    # n=12, t=1, k/t=4 even
    (4, 8, [-256, 0, 256], false),             # n=12, t=4, k/t=1 odd
    (4, 11, [-128, -64, 0, 64, 128], false),   # n=12, t=1, k/t=4 even
    (5, 1, [-256, 0, 256], false),             # n=15, t=1, k/t=5 odd (AB)
    (5, 10, [-1024, 0, 1024], false),          # n=15, t=5, k/t=1 odd
    (5, 4, [-256, 0, 256], true),              # n=15, t=1, k/t=5 odd
    (5, 7, [-256, 0, 256], true),              # n=15, t=1, k/t=5 odd
    (5, 13, [-256, 0, 256], true),             # n=15, t=1, k/t=5 odd
]

"""
    walsh_bound(n, t) -> Int

Lemma 4.2's bound: `2^{(n+t)/2}` when `n+t` is even, `2^{(n+t-1)/2}` when odd.
"""
walsh_bound(n::Int, t::Int) = 1 << ((n + t) ÷ 2)

"""
    lemma4_1_check(; trials = 8, seed = 20120504) -> NamedTuple

Randomised check of Lemma 4.1 (BTT-11): for `gcd(n, s) = 1` and
`G(x) = Σ_{i=0}^{d} r_i x^{2^{s i}}`, the equation `G(x) = 0` has at most `2^d`
solutions.  Roots are counted exhaustively over `GF(2ⁿ)` for small `n`, so the
per-trial cost is `O(d · n · 2ⁿ)`; `trials` is the explicit budget.

Measured here: 8 trials over `n ∈ {6,8,9}`, `d ≤ 3` in 0.4 s; every trial found
exactly 2 roots, comfortably inside the `2^d` bound.
"""
function lemma4_1_check(; trials::Integer = 8, seed::Integer = 20120504)
    rng = MersenneTwister(Int(seed))
    ok = true
    rows = NamedTuple[]
    for _ = 1:Int(trials)
        n = rand(rng, (6, 8, 9))
        s = rand(rng, [j for j = 1:(n - 1) if gcd(j, n) == 1])
        d = rand(rng, 1:3)
        r = [rand(rng, 0:((1 << n) - 1)) for _ = 0:d]
        all(==(0), r) && (r[1] = 1)
        modulus = primitive_polynomial(n)
        cnt = 0
        for x = 0:((1 << n) - 1)
            acc = 0
            for i = 0:d
                acc ⊻= gf_mul(
                    r[i + 1],
                    gf_pow(x, 1 << (s * i), n; modulus = modulus),
                    n;
                    modulus = modulus,
                )
            end
            acc == 0 && (cnt += 1)
        end
        pass = cnt ≤ (1 << d)
        ok &= pass
        push!(rows, (n = n, s = s, d = d, roots = cnt, bound = 1 << d, pass = pass))
    end
    (ok = ok, rows = rows)
end

function section4_report(io::IO = stdout; full_search::Bool = false)
    print_section("Section 4 — F is highly nonlinear (Lemmas 4.1, 4.2; Theorem 1.1)", io)
    println(io, "  Lemma 4.1: Σ_{i≤d} r_i x^{2^{si}} = 0 has ≤ 2^d roots when gcd(n,s)=1.")
    println(io, "  Lemma 4.2: |F^W(a,b)| ≤ 2^{(n+t)/2}   when n+t even")
    println(io, "             |F^W(a,b)| ≤ 2^{(n+t-1)/2} when n+t odd")
    println(io, "             — stated for F of Theorem 1.2, hence only for k/t ODD.")
    println(io, "  Theorem 1.1 (t=2): Walsh spectrum ⊆ {0, ±2^{n/2}, ±2^{(n+2)/2}}.")
    println(io, "  We record the full signed value set, not just its maximum: a bound")
    println(io, "  cannot certify a set claim, and Section 5's separation of F from the")
    println(io, "  inverse function rests on the set (BTT-3).")
    println(io, "  n=15 uses column-at-a-time streaming (the full LAT would be ~8 GB).")
    println(io)

    l41 = lemma4_1_check()
    for r in l41.rows
        print_check("Lemma 4.1: n=$(r.n), s=$(r.s), d=$(r.d) → $(r.roots) roots ≤ 2^$(r.d) = $(r.bound)",
                    r.pass, io)
    end
    println(io)

    all_pass = l41.ok
    for (k, s, expected, heavy) in SECTION4_CASES
        (heavy && !full_search) && continue
        n, t = 3k, gcd(3k, s)
        F = bracken_binomial_sbox(k, s)
        vals = walsh_value_set(F)
        L = maximum(abs, vals)
        set_ok = vals == expected
        if isodd(k ÷ t)
            bound = walsh_bound(n, t)
            ok = set_ok && L ≤ bound
            print_check("n=$n, k=$k, s=$s, t=$t (k/t odd) → |F^W| ≤ 2^$((n + t) ÷ 2) = $bound" *
                        "  [max $L, set $(walsh_set_string(vals))]", ok, io)
        else
            # Outside Theorem 1.2 (Lemma 2.1's non-permutation branch): Lemma 4.2
            # is NOT claimed here, and the bound is in fact exceeded — recorded
            # as scope evidence, never asserted.
            ok = set_ok
            bound = walsh_bound(n, t)
            print_check("n=$n, k=$k, s=$s, t=$t (k/t even, outside Thm 1.2) → set recorded" *
                        "  [max $L vs Lemma 4.2 bound $bound, set $(walsh_set_string(vals))]",
                        ok, io)
        end
        all_pass &= ok
    end
    println(io)

    # Theorem 1.1's set claim, at its only feasible instance below n = 30.
    F6 = bracken_binomial_sbox(2, 4)
    vals6 = walsh_value_set(F6)
    allowed6 = Set([0, 8, -8, 16, -16])       # {0, ±2^{n/2}, ±2^{(n+2)/2}}, n=6
    thm11 = issubset(Set(vals6), allowed6)
    print_check("Theorem 1.1 set claim, n=6 (k=2,s=4,t=2): $(walsh_set_string(vals6)) ⊆ " *
                "{0, ±2^3, ±2^4}", thm11, io)
    print_kv("Theorem 1.1 caveat",
             "n=6 is a DEGENERATE monomial instance (both exponents ≡ 17 mod 63); " *
             "the smallest genuine binomial with t=2 is n=30 — see theorem1_1.jl", io)
    all_pass &= thm11

    println(io)
    print_check("All Section 4 checks pass", all_pass, io)
    print_kv("completeness",
             (full_search ? "12 of 12" : "9 of 12") *
             " feasible instances with n = 3k ≤ 15, each exhaustive over all " *
             "(a,b) ≠ (0,0); Lemma 4.2 asserted only on the k/t odd rows it covers", io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    section4_report()
end
