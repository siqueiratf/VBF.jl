# Aggregate report for the Edel & Pott (2009) reproduction.
# Paper: Edel, Pott (2009), "A new almost perfect nonlinear function which is
#        not quadratic", Adv. Math. Commun. 3(1):59-81.
# Section: General — aggregate report driver.
#
# VBF API used: (all calls delegated to included files)

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "proposition2.jl"))
include(joinpath(@__DIR__, "theorem9.jl"))
include(joinpath(@__DIR__, "table5.jl"))
include(joinpath(@__DIR__, "table6.jl"))
include(joinpath(@__DIR__, "theorem7.jl"))
include(joinpath(@__DIR__, "theorem10.jl"))
include(joinpath(@__DIR__, "theorem11.jl"))

"""
    paper_report(io = stdout; save_results = false, full_search = false) -> NamedTuple

Run every bounded/default reproducible check for Edel–Pott (2009) and print a
structured report. The full `n = 6` sweep (Tables 5, 6; Theorems 7, 9, 10, 11)
completes in seconds; `full_search = true` adds the `n = 7` Corollary-8 ranks.
"""
function paper_report(io::IO = stdout; save_results::Bool = false, full_search::Bool = false)
    print_header(io)

    r_prop2 = proposition2_report(io; max_n = 8, save_results)
    r_thm9  = theorem9_report(io; save_results)
    r_tab5  = table5_report(io; save_results)
    r_tab6  = table6_report(io; save_results)
    r_thm7  = theorem7_report(io; full_search, save_results)
    r_thm10 = theorem10_report(io; save_results)
    r_thm11 = theorem11_report(io; save_results)

    print_section("summary", io)
    print_check("Proposition 2 — x^3+tr(x^9) APN (n=2..8)", r_prop2.all_apn, io)
    print_check("Theorem 9 — switching iff criterion (2.3→2.11)",
        r_thm9.constraint_ok && r_thm9.perturbed_apn_lost, io)
    print_check("Table 5 — all 14 reps APN; exactly one non-quadratic (2.11)",
        r_tab5.all_apn && r_tab5.nonquad == ["2.11"], io)
    print_check("Table 6 — Γ/Δ-rank + Walsh class match paper (14 reps)", r_tab6.all_ok, io)
    print_check("Theorem 7 — 2.11 Δ-rank 152 > 128 ⇒ not crooked", r_thm7.all_quad_ok, io)
    print_check("Theorem 10 — 2.11 |M| ∤ 63,64 ⇒ not power/quadratic (published |M|)",
        r_thm10.v211_not_power && r_thm10.v211_not_quad, io)
    print_check("Theorem 11 — new non-quadratic APN: deg 3, Γ/Δ (1300,152), " *
        "CCZ≠x^3", r_thm11.deg == 3 && r_thm11.gamma == 1300 && r_thm11.delta == 152 &&
        r_thm11.not_crooked && r_thm11.ccz_to_gold == false, io)

    println(io, "\n  [SCOPE] exact (n=6): Tables 5,6; Theorems 7,11; degree/APN/ranks/Walsh")
    println(io, "  [SCOPE] bounded demo: Proposition 2 (n≤8); Theorem 9 constraint enum")
    println(io, "  [SCOPE] reasoning only: Theorem 10 (|M(G_F)| is MAGMA — not executed)")
    println(io, "  [SCOPE] opt-in: Corollary 8 n=7 Kasami Δ-ranks (full_search=true)")

    result = (; proposition2 = r_prop2, theorem9 = r_thm9, table5 = r_tab5,
        table6 = r_tab6, theorem7 = r_thm7, theorem10 = r_thm10, theorem11 = r_thm11)
    if save_results
        table5_ok = r_tab5.all_apn && r_tab5.nonquad == ["2.11"]
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "report.toml"), "w") do f
            println(f, "# Edel–Pott (2009) aggregate report")
            println(f, "proposition2_ok = $(r_prop2.all_apn)")
            println(f, "table5_ok = $(table5_ok)")
            println(f, "table6_ok = $(r_tab6.all_ok)")
            println(f, "theorem11_degree = $(r_thm11.deg)")
            println(f, "theorem11_gamma = $(r_thm11.gamma)")
            println(f, "theorem11_delta = $(r_thm11.delta)")
        end
    end
    return result
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
