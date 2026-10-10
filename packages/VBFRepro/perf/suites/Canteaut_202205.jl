# packages/VBFRepro/perf/suites/Canteaut_202205.jl — reproduction-benchmark case.
#
# CONTRACT: the same one packages/VBF/perf/suites/01_representations.jl states, plus one
# rule: this file is READ-ONLY against papers/2022/Canteaut_202205/. It only
# `include`s the paper's own report.jl, unmodified.
#
# Paper: Canteaut, Couvreur, Perrin (2022),
#        "Recovering or Testing Extended-Affine Equivalence".
# Mode: hybrid. The default reproduction runs Algorithm 1 (EA-recovery via
#       Jacobian matrices, at n=5,7,9), whose guess-and-solve search and packed
#       linear-system builder are paper-specific, alongside VBF core calls
#       (rank_table, F2LinearMap, is_invertible). `verify_min_ea=false` keeps
#       Section 4.4's opt-in ~25-30 minute sweep off.
# Entry point: report.jl:paper_report(io; n_values, verify_min_ea)

module Bench_Canteaut_202205
using VBF, VBFCatalog
const PAPER_DIR = normpath(joinpath(@__DIR__, "..", "..", "papers", "2022", "Canteaut_202205"))
cd(() -> include(joinpath(PAPER_DIR, "report.jl")), PAPER_DIR)
end

function register!(reg)
    call = _ -> Bench_Canteaut_202205.paper_report(devnull;
        n_values = [5, 6], verify_min_ea = false)
    benchmark!(reg; group = "papers", name = "Canteaut_202205_report", cost = 3, samples = 1,
           paper_id = "Canteaut_202205", mode = "hybrid",
           approach = "ea_recovery_jacobian",
           setup = () -> nothing, call = call,
           note = "Algorithm 1 at n_values=[5,6]; verify_min_ea=false")
end
