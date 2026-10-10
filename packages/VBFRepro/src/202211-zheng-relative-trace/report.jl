# Aggregate report for the Zheng–Kan–Li–Peng–Tang (2022) reproduction.
# Paper: Zheng, Kan, Li, Peng, Tang (2022), "Constructing new APN functions through
#        relative trace functions", arXiv:2101.11535v1 [cs.IT]
# Section: General — aggregate report driver
#
# VBF API used: (all calls delegated to included files)

using Dates
include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "lemma2_1.jl"))
include(joinpath(@__DIR__, "theorem3_3.jl"))

"""
    paper_report(io::IO = stdout; save_results = false) -> NamedTuple

Run all bounded/default reproducible checks for Zheng et al. (2022) and
print a structured report. Returns a NamedTuple of per-claim results.

Scope:
  exact        — Lemma 2.1 APN criterion (exhaustive at n=10)
  exact        — Theorem 3.3 Case iii APN at n=10 (full DDT) and n=14 (streaming)
  partial      — Table II CCZ-inequivalence at n=10 via EA-mugshot vs. catalog
  out-of-scope — Hexanomial families (Section 3B), sporadic instances, full sboxU test
"""
function paper_report(io::IO = stdout; save_results::Bool = false)
    print_header(io)
    println(io)
    println(io, "Julia $(VERSION) — $(Dates.now())")
    println(io, "Parameters: a=2, b=2, s=3, c=b³, n∈{10,14}")

    r_lemma = lemma2_1_report(io; m = 5, a = 2, b = 2)
    r_thm   = theorem3_3_report(io; m_values = [5, 7], a = 2, b = 2, save_results)

    print_section("Paper summary", io)
    print_check("Lemma 2.1 APN criterion (exhaustive n=10)",   r_lemma.agree, io)
    print_check("Theorem 3.3 Case iii conditions verified",    r_thm.all_cond_ok, io)
    print_check("F15 APN at n=10 and n=14",                   r_thm.all_apn_ok, io)
    if !isnothing(r_thm.ccz)
        print_check("Table II mugshot distinct from catalog n=10",
                    r_thm.ccz.distinct_from_all, io)
    end

    println(io, "\n  [NOTE] Section 3B hexanomial families: out-of-scope (CCZ-to-Taniguchi check).")
    println(io, "  [NOTE] Sporadic n=10 instances: out-of-scope (exhaustive computer search).")
    println(io, "  [NOTE] Full CCZ-inequivalence at n=14: out-of-scope (sboxU code-isomorphism).")

    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "report.toml"), "w") do f
            println(f, "# Zheng et al. (2022) aggregate report")
            println(f, "lemma2_1_agree = $(r_lemma.agree)")
            println(f, "lemma2_1_du = $(r_lemma.du)")
            println(f, "theorem3_3_conditions_ok = $(r_thm.all_cond_ok)")
            println(f, "theorem3_3_apn_ok = $(r_thm.all_apn_ok)")
        end
    end

    return (; lemma = r_lemma, theorem = r_thm)
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
