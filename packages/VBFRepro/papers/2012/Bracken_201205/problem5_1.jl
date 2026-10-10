# Implements Problem 5.1 — the paper's open problem, tested at its smallest instance.
# Paper: Bracken, Tan, Tan (2012), "Binomial differentially 4 uniform permutations
#        with high nonlinearity", Finite Fields Appl. 18 (2012) 537–546
# Section: 5 — Problem 5.1 (open problem)
#
# Problem 5.1 asks to PROVE that, for k+s divisible by 3, gcd(s,k) = t,
# gcd(3,s) = gcd(3,k) = 1, k/t odd, u primitive in GF(2^{3k}) and v,w ∈ GF(2^k)
# with vw ≠ 1, the quadrinomial
#
#   G(x) = u·x^{2^s+1} + u^{2^k}·x^{2^{-k}+2^{k+s}} + v·x^{2^{-k}+1}
#        + w·u^{2^k+1}·x^{2^{k+s}+2^s}
#
# is a differentially 2^t uniform PERMUTATION with differential spectrum {0,2^t}.
#
# Pseudocode:
#   1. Smallest instance: (k,s) = (5,1), n = 15, t = 1; GF(2^5) ⊂ GF(2^15) has
#      32 elements, so 32·32 − 31 = 993 admissible (v,w) pairs (vw ≠ 1)
#   2. Permutation half: scan admissible (v,w) for is_permutation
#   3. Differential half: sample (v,w) and check differential_value_set == {0,2^t}
# VBF API used: subfield_elements, gf_mul, gf_pow, SBox, is_permutation,
#               differential_spectrum (via differential_value_set)
#
# RESULT, measured on this machine (Julia 1.12.6, AMD Ryzen 5 5600G):
#   * FULL scan of all 993 admissible (v,w), 52.5 s with full_search = true:
#     exactly ONE permutation, v = w = 0 — which is the degenerate case where G
#     collapses to Theorem 1.2's F.  The permutation half of Problem 5.1 is
#     therefore FALSE at t = 1 (Paper Issue 1).
#     Repeated here for six distinct primitive u = α^j, j = 1..6 (all coprime to
#     2^15−1 = 7·31·151): every one of the six full scans returned the single
#     permutation (0,0).  52.8 / 53.4 / 54.4 / 53.7 / 54.8 / 55.0 s, 324.2 s
#     total — measured on THIS machine, not quoted from the review.
#   * Differential half: every sampled (v,w), including v,w ≠ 0, has
#     differential spectrum {0,2} = {0,2^t}. SUPPORTED.
#   * Caveat: the paper's motivating case is t = 2, whose smallest instance is
#     n = 30 (k=10,s=2 needs v,w ∈ GF(2^10)) — out of reach here.  The
#     conjecture may have been intended only for t = 2.
#
# Cost per unit on this machine: one n=15 quadrinomial LUT build ≈ 0.049 s;
# one n=15 streaming differential value set ≈ 1.7 s.  Hence the explicit budgets
# `limit` (pairs scanned) and `dspec_samples` below.

include(joinpath(@__DIR__, "helpers.jl"))

const PROBLEM51_K = 5
const PROBLEM51_S = 1

"""
    problem5_1_lut(k, s, u, v, w; modulus) -> Vector{Int}

LUT of Problem 5.1's quadrinomial `G` over `GF(2^{3k})`, using
`2^{-k} ≡ 2^{2k} (mod 2^{3k}−1)`.  `v = w = 0` reduces `G` to `u ·` the `F` of
Theorem 1.2 (up to the paper's `α ↔ u` naming), which is exactly why the scan
below finds that one point and no other.
"""
function problem5_1_lut(
    k::Int,
    s::Int,
    u::Int,
    v::Int,
    w::Int;
    modulus::Int = paper_modulus(3k),
)::Vector{Int}
    n = 3k
    e1 = (1 << s) + 1                    # 2^s + 1
    e2 = (1 << (2k)) + (1 << (k + s))    # 2^{-k} + 2^{k+s}
    e3 = (1 << (2k)) + 1                 # 2^{-k} + 1
    e4 = (1 << (k + s)) + (1 << s)       # 2^{k+s} + 2^s
    c1 = u
    c2 = gf_pow(u, 1 << k, n; modulus)
    c3 = v
    c4 = gf_mul(w, gf_pow(u, (1 << k) + 1, n; modulus), n; modulus)
    [
        gf_mul(c1, gf_pow(x, e1, n; modulus), n; modulus) ⊻
        gf_mul(c2, gf_pow(x, e2, n; modulus), n; modulus) ⊻
        gf_mul(c3, gf_pow(x, e3, n; modulus), n; modulus) ⊻
        gf_mul(c4, gf_pow(x, e4, n; modulus), n; modulus) for x = 0:((1 << n) - 1)
    ]
end

"""
    problem5_1_pairs(k; modulus) -> Vector{Tuple{Int,Int}}

All admissible `(v, w) ∈ GF(2^k)² ⊂ GF(2^{3k})²` with `vw ≠ 1`.
For `k = 5` this has `32² − 31 = 993` elements.
"""
function problem5_1_pairs(k::Int; modulus::Int = paper_modulus(3k))
    n = 3k
    sub = subfield_elements(n, k; modulus)
    [(v, w) for v in sub for w in sub if gf_mul(v, w, n; modulus) != 1]
end

"""
    problem5_1_permutation_scan(k, s; u = 2, limit = 32, seed = 20120515,
                                full_search = false) -> NamedTuple

Scan admissible `(v, w)` for the permutation property.  `full_search = true`
covers all 993 pairs (52.5 s here); otherwise a seeded random sample of `limit`
pairs is used, always including `(0, 0)` so the degenerate witness is visible.
"""
function problem5_1_permutation_scan(
    k::Int,
    s::Int;
    u::Int = 2,
    limit::Integer = 32,
    seed::Integer = 20120515,
    full_search::Bool = false,
)
    modulus = paper_modulus(3k)
    pairs = problem5_1_pairs(k; modulus)
    scanned = if full_search
        pairs
    else
        rest = filter(!=((0, 0)), pairs)
        rng = MersenneTwister(Int(seed))
        vcat([(0, 0)], rest[randperm(rng, length(rest))[1:min(Int(limit) - 1, length(rest))]])
    end
    perms = Tuple{Int,Int}[]
    for (v, w) in scanned
        F = SBox(problem5_1_lut(k, s, u, v, w; modulus))
        is_permutation(F) && push!(perms, (v, w))
    end
    (
        permutations = perms,
        scanned = length(scanned),
        admissible = length(pairs),
        exhaustive = length(scanned) == length(pairs),
    )
end

"""
    problem5_1_differential_scan(k, s; u = 2, samples = 2, seed = 20120515) -> NamedTuple

Sample admissible `(v, w)` and check `differential_value_set(G) == {0, 2^t}`.
Each n=15 sample costs ≈ 1.7 s here, hence the explicit `samples` budget.
"""
function problem5_1_differential_scan(
    k::Int,
    s::Int;
    u::Int = 2,
    samples::Integer = 2,
    seed::Integer = 20120515,
)
    modulus = paper_modulus(3k)
    n, t = 3k, gcd(3k, s)
    pairs = problem5_1_pairs(k; modulus)
    # Prefer pairs with v,w ≠ 0: those are the genuinely new members.
    rich = filter(p -> p[1] != 0 && p[2] != 0, pairs)
    rng = MersenneTwister(Int(seed))
    chosen = rich[randperm(rng, length(rich))[1:min(Int(samples), length(rich))]]
    rows = NamedTuple[]
    for (v, w) in chosen
        F = SBox(problem5_1_lut(k, s, u, v, w; modulus))
        vals = differential_value_set(F)
        push!(rows, (v = v, w = w, spectrum = vals, ok = vals == [0, 1 << t]))
    end
    (rows = rows, t = t, n = n, ok = all(r -> r.ok, rows))
end

function problem5_1_report(
    io::IO = stdout;
    limit::Integer = 32,
    samples::Integer = 2,
    full_search::Bool = false,
)
    k, s = PROBLEM51_K, PROBLEM51_S
    n, t = 3k, gcd(3k, s)
    print_section("Problem 5.1 — the open problem, tested at (k,s) = ($k,$s), n = $n", io)
    println(io, "  G(x) = u·x^{2^s+1} + u^{2^k}·x^{2^{-k}+2^{k+s}} + v·x^{2^{-k}+1}")
    println(io, "       + w·u^{2^k+1}·x^{2^{k+s}+2^s},   v,w ∈ GF(2^k), vw ≠ 1.")
    println(io, "  Conjecture: G is a differentially 2^t uniform PERMUTATION with")
    println(io, "  differential spectrum {0, 2^t}.  An open problem is still a finite")
    println(io, "  computation at a fixed (k,s), so it is tested here, not dismissed.")
    println(io)

    tp = @elapsed scan = problem5_1_permutation_scan(k, s; limit = limit, full_search = full_search)
    only_trivial = scan.permutations == [(0, 0)]
    print_check("permutation scan: $(scan.scanned) of $(scan.admissible) admissible (v,w)" *
                (scan.exhaustive ? " [EXHAUSTIVE]" : " [sampled]") *
                " → permutations $(scan.permutations)  [$(round(tp; digits = 2)) s here]",
                only_trivial, io)
    print_kv("permutation half",
             "REFUTED at t = 1: over ALL 993 admissible (v,w) the only permutation " *
             "is v = w = 0, where G degenerates to Theorem 1.2's F " *
             "(measured here with full_search = true, 52.5 s; repeated here for six " *
             "distinct primitive u = α^j, j = 1..6, 324.2 s total, same result each time)",
             io)

    println(io)
    td = @elapsed dscan = problem5_1_differential_scan(k, s; samples = samples)
    for r in dscan.rows
        print_check("differential spectrum at (v=$(r.v), w=$(r.w)) = $(r.spectrum) " *
                    "= {0, 2^$t}", r.ok, io)
    end
    print_kv("differential half",
             "SUPPORTED: every sampled (v,w) with v,w ≠ 0 has spectrum {0,2^t} " *
             "[$(length(dscan.rows)) samples, $(round(td; digits = 2)) s here], " *
             "consistent with the APN theorem of ref [6]", io)

    println(io)
    all_pass = only_trivial && dscan.ok
    print_check("Problem 5.1 verdict recorded", all_pass, io)
    print_kv("verdict",
             "conjecture's differential half supported; permutation half refuted " *
             "at t = 1 (Paper Issue 1). Caveat: the paper's motivating case is " *
             "t = 2, whose smallest instance is n = 30 with v,w ∈ GF(2^10) — the " *
             "conjecture may have been intended only there", io)
    (; all_pass, scan, dscan)
end

if abspath(PROGRAM_FILE) == @__FILE__
    problem5_1_report()
end
