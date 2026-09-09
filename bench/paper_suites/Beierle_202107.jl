# bench/paper_suites/Beierle_202107.jl — two reproduction-benchmark cases.
#
# CONTRACT: the same one bench/suites/01_representations.jl states, plus one
# rule: this file is READ-ONLY against papers/2021/Beierle_202107/. It only
# `include`s the paper's own report.jl (which itself includes algorithm1.jl),
# unmodified.
#
# Paper: Beierle, Brinkmann, Leander (2021),
#        "Linearly Self-Equivalent APN Permutations in Small Dimension".
#
# Two units, because report.jl does not call the paper's own search:
#
#   * "_report" (mode=hybrid): report.jl's default reproduction. Table 1 runs
#     the paper-specific admissibility filters (proposition4_filter,
#     proposition5_filter); Theorem 1 and the n=7 monomial check only load a
#     STORED search result and verify it with core VBF calls
#     (differential_uniformity, are_ccz_equivalent, algebraic_degree). No
#     search runs live.
#   * "_algorithm1" (mode=paper_specific): Algorithm 1 itself — the
#     backtracking tuple search (APNSearch) — run live and bounded, since
#     report.jl never calls it. n=6, class 5 is the paper's own Theorem 1
#     example; bounded by max_solutions=1 and timeout_seconds=60.

module Bench_Beierle_202107
using VBF, VBFCatalog
const PAPER_DIR = normpath(joinpath(@__DIR__, "..", "..", "papers", "2021", "Beierle_202107"))
cd(() -> include(joinpath(PAPER_DIR, "report.jl")), PAPER_DIR)
end

function register!(reg)
    report_call = _ -> Bench_Beierle_202107.paper_report(devnull)
    bench!(reg; group = "papers", name = "Beierle_202107_report", cost = 2, reps = 1,
           paper_id = "Beierle_202107", mode = "hybrid",
           approach = "linear_self_equivalence_tables",
           setup = () -> nothing, call = report_call,
           note = "report.jl: Table 1 admissibility filters (paper-specific) + verification of a STORED search result (VBF core); no live search")

    search_call = _ -> Bench_Beierle_202107.APNSearch(
        6, Bench_Beierle_202107.precomputed_tuple_matrices(6, 5)...;
        max_solutions = 1, timeout_seconds = 60.0)
    bench!(reg; group = "papers", name = "Beierle_202107_algorithm1", cost = 3,
           paper_id = "Beierle_202107", mode = "paper_specific",
           approach = "tuple_orbit_backtracking",
           setup = () -> nothing, call = search_call,
           note = "Algorithm 1 depth-first tuple search, n=6 class 5, bounded by max_solutions=1 and timeout_seconds=60")
end
