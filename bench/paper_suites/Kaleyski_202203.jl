# bench/paper_suites/Kaleyski_202203.jl — reproduction-benchmark case.
#
# CONTRACT: the same one bench/suites/01_representations.jl states, plus one
# rule: this file is READ-ONLY against papers/2022/Kaleyski_202203/. It only
# `include`s the paper's own report.jl, unmodified.
#
# Paper: Kaleyski, N. (2022), "Deciding EA-equivalence via invariants",
#        Cryptography and Communications.
# Mode: core_only. report.jl's default reproduction calls only VBF-exported
#       equivalence functions (ea_partition, partition_automorphisms,
#       enumerate_bucket_maps, outer_permutations, inner_permutation — all
#       defined in packages/VBF/src/equivalence/ea/). No paper-local
#       algorithmic code runs; the paper files are orchestration only.
# Entry point: report.jl:paper_report(io; n_values, save_results)

module Bench_Kaleyski_202203
using VBF, VBFCatalog
const PAPER_DIR = normpath(joinpath(@__DIR__, "..", "..", "papers", "2022", "Kaleyski_202203"))
cd(() -> include(joinpath(PAPER_DIR, "report.jl")), PAPER_DIR)
end

function register!(reg)
    call = _ -> Bench_Kaleyski_202203.paper_report(devnull; n_values = [5, 6])
    bench!(reg; group = "papers", name = "Kaleyski_202203_report", cost = 2,
           paper_id = "Kaleyski_202203", mode = "core_only",
           approach = "ea_equivalence_invariants",
           setup = () -> nothing, call = call,
           note = "report.jl default reproduction, n_values=[5,6]; core_only — no bespoke search runs")
end
