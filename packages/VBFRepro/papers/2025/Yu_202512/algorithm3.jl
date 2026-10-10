# Implements Algorithm 3 — Partial search for APN functions on GF(2^11)
# Paper: Yu, Li, Ichanska, Kaleyski (2025)
# Section: 4.2 Further observation, Algorithm 3
#
# Pseudocode (Algorithm 3 for n=11, generalised):
#   for a, b, c, d, e ∈ F_{11}:    (all variables restricted to F_n, not just the first)
#     if k-th order upper-left corner of H_{11} is proper for k=2,3,4,5,6:
#       if IsQAM(11, H_{11}): generate APN from H_{11}
#
# The key difference from Algorithm 2: ALL free variables are restricted to F_n
# (not just the first one), making it a partial search.
# This is ≈ 11^4 ≈ 14641 times faster than Algorithm 2 for n=11 (paper's claim).
# VBF API used: conway_polynomial

include(joinpath(@__DIR__, "algorithm2.jl"))

"""
    partial_search_apn_f2(n; limit, max_evaluations, modulus) -> Int

Algorithm 3: partial search — restricts ALL free variables to Fₙ (not just the first).
For n=11, this is ≈ n^{floor(n/2)-1} times faster than the full Algorithm 2 while
still finding representatives of each CCZ-class (conjectured by the paper).
Returns raw count of APN H matrices found.
"""
function partial_search_apn_f2(
    n::Int;
    limit::Int           = 200,
    max_evaluations::Int = 1 << 20,
    modulus::Int          = conway_polynomial(n),
)
    num_vars = n ÷ 2
    cr      = get_cyclic_reps(n)
    id_arr  = get_indices(n, cr)
    fn      = fn_set(n; modulus = modulus)

    # Algorithm 3: non-first, non-self-paired variables use Fₙ instead of GF(2^n)*.
    # Self-paired diagonal (2d=n) must keep GF(2^{n/2})* to satisfy Theorem 1's
    # self-pairing constraint (c^{2^{n/2}}=c); Fₙ elements have orbit size n, not n/2.
    domains = [
        k == 1       ? fn :
        2k == n      ? subfield_nonzero(k, n; modulus = modulus) :
        fn
        for k in 1:num_vars
    ]

    H     = zeros(Int, n, n)
    count = Ref(0)
    evals = Ref(max_evaluations)
    _dfs!(H, 1, n, num_vars, cr, id_arr, domains, count, limit, evals; modulus = modulus)
    count[]
end

function algorithm3_report(io::IO = stdout)
    print_section(io, "Algorithm 3: partial search (all variables from Fₙ)")

    # Demo for n=6 (same as Algorithm 2 at n=6 restricted to F₆)
    n6  = 6
    mod6 = conway_polynomial(n6)
    fn6  = fn_set(n6; modulus=mod6)
    print_kv(io, "n=6: |F₆|", length(fn6))
    t0 = time()
    cnt6 = partial_search_apn_f2(n6; limit=200, max_evaluations=1<<18, modulus=mod6)
    print_kv(io, "n=6: partial search count", cnt6)
    print_kv(io, "n=6: time (s)", round(time()-t0, digits=3))

    # Algorithm 3 for n=7 (small budget)
    n7  = 7
    mod7 = conway_polynomial(n7)
    fn7  = fn_set(n7; modulus=mod7)
    print_kv(io, "n=7: |F₇|", length(fn7))
    t0 = time()
    cnt7 = partial_search_apn_f2(n7; limit=200, max_evaluations=1<<18, modulus=mod7)
    print_kv(io, "n=7: partial search count (budget-limited)", cnt7)
    print_kv(io, "n=7: time (s)", round(time()-t0, digits=3))

    print_kv(io, "n=11 full partial search", "out of scope (15 Magma scripts, 12 days)")
    print_kv(io, "n=11 modulus used", 2053)
    print_kv(io, "completeness", "demo only; n=11 full run not executed")
end

if abspath(PROGRAM_FILE) == @__FILE__
    algorithm3_report()
end
