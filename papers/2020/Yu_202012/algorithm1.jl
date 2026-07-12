# Implements Section 3.2, Algorithm 1
# Paper: Yu, Kaleyski, Budaghyan, Li (2020),
#   "Classification of quadratic APN functions with coefficients in F₂ for dimensions up to 9"
# Section: 3.2 — Algorithm 1: output quadratic APN polynomials with 0,1 coefficients
#
# ─── SUBSTITUTION NOTICE (do not read this file as "Algorithm 1 reproduced") ──
# This is NOT the paper's algorithm. It is a one-line wrapper over VBF's `search_qam(n,1)`,
# and the difference is material enough to name:
#
#   THE PAPER'S ALGORITHM 1        │  WHAT WE ACTUALLY RUN
#   ───────────────────────────────┼──────────────────────────────────────────────
#   GetNoneSquare(n): restrict the │  no orbit reduction on the leading variable
#     leading free variable to one │  (VBF exports `independent_conjugate_elements`
#     representative per orbit     │   for this but `search_qam` does not use it)
#   TranFirRow(j, H): fill column  │  a plain odometer sweep over the free variables
#     j, propagate, recurse        │  of `qam_cyclic_orbits(n,1)`
#   GetElemC(j, H): prune by span  │  NO pruning — every candidate matrix is built
#     size (#S < 2^{2j−4}) and by  │  and tested whole by the exact `is_cyclic_qam`
#     proper-submatrix rank        │  oracle
#
# Result-equivalent at small n (both are exhaustive over the same space, and the oracle is
# exact), but it is the missing pruning that puts the paper's own targets out of reach:
# n=8 has 2.7×10⁸ candidates and n=9 has 6.9×10¹⁰. So the CLASSIFICATION ITSELF is
# reproduced only for n ≤ 7 (see test_algorithm1.jl, which runs the full n=7 sweep and
# checks it against Table 2). n=8 and n=9 are NOT re-derived here; their tables are
# verified as given.
#
# ─── CLASS COUNTS ARE LOWER BOUNDS ───────────────────────────────────────────
# `search_qam` de-duplicates its results by `apn_ea_mugshot`, and that key MERGES
# CCZ-inequivalent functions: at n=7 it merges Gold x³ with x⁹, and at n=5 x³ with x⁵.
# So `length(algorithm1_run(n))` is a LOWER BOUND on the number of CCZ classes, never an
# equality. Concretely, at n=7 it returns 14 where the true count is 15 — the missing one
# is exactly the Gold x³/x⁹ split (table2.jl settles that split with the complete EA
# decision). Never quote this length as a class count without that correction.
#
# VBF API used: search_qam (substituted for the paper's pruned Algorithm 1)

include(joinpath(@__DIR__, "helpers.jl"))

"""
    algorithm1_run(n; limit, max_evaluations) -> Vector{SBox{n}}

Enumerate F₂-cyclic QAMs over GF(2ⁿ) and return one representative per EA-mugshot class.

**Substitutes** `search_qam(n, 1)` for the paper's pruned Algorithm 1 (see the header:
no `GetNoneSquare` orbit reduction, no `GetElemC` span/submatrix pruning). Exhaustive
over the same search space, so result-equivalent at small `n`, but much heavier per
candidate.

The returned length is a **lower bound** on the CCZ-class count — the EA-mugshot
de-duplication key merges CCZ-inequivalent functions (Gold x³/x⁹ at n=7).
"""
function algorithm1_run(
    n::Int;
    limit::Int = typemax(Int),
    max_evaluations::Int = 1 << 20,
)
    search_qam(n, 1; limit = limit, max_evaluations = max_evaluations)
end

"""
    algorithm1_report(io; n_demo, max_evaluations)

Demo the (substituted) Algorithm 1 for n=6 — exhaustive, ≤ 2¹⁵ candidates (Example 1).
"""
function algorithm1_report(
    io::IO = stdout;
    n_demo::Int = 6,
    max_evaluations::Int = 1 << 24,
)
    print_section(io, "Algorithm 1 — F₂-coefficient QAM search (demo: n=$n_demo)")
    print_kv(io, "implementation", "SUBSTITUTED: VBF search_qam(n,1) — an unpruned " *
             "odometer sweep with an exact oracle, NOT the paper's pruned Algorithm 1")
    print_kv(io, "n", n_demo)
    print_kv(io, "max_evaluations", max_evaluations)
    result = algorithm1_run(n_demo; max_evaluations = max_evaluations)
    print_kv(io, "distinct EA-mugshot classes found", length(result))
    print_kv(io, "class count is a", "LOWER BOUND (mugshot key merges CCZ-inequivalent " *
             "functions; at n=7 it returns 14 for 15 true classes)")
    print_kv(io, "completeness", "exhaustive (n=$n_demo search space = 2^15, per Example 1)")
    print_kv(io, "expected (Table 1)", 1)
    all_apn = all(differential_uniformity(F) == 2 for F in result)
    print_check(io, "all found functions are APN", all_apn)
    (; n_demo, n_classes = length(result), exhaustive = true)
end

if abspath(PROGRAM_FILE) == @__FILE__
    algorithm1_report()
end
