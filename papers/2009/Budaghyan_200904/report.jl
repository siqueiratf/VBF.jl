# Aggregate report for the Budaghyan–Carlet–Leander (2009) reproduction.
# Paper: Budaghyan, Carlet, Leander (2009), "Constructing new APN functions from
#        known ones", Finite Fields Appl. 15 (2009) 150–159.
# Section: General — aggregate report driver
#
# VBF API used: (all calls delegated to the included per-claim files)

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "theorem1.jl"))
include(joinpath(@__DIR__, "proposition1.jl"))
include(joinpath(@__DIR__, "corollary1.jl"))
include(joinpath(@__DIR__, "proposition2.jl"))
include(joinpath(@__DIR__, "theorem2.jl"))
include(joinpath(@__DIR__, "corollary2.jl"))
include(joinpath(@__DIR__, "section2_1.jl"))
include(joinpath(@__DIR__, "theorem3.jl"))
include(joinpath(@__DIR__, "corollary3.jl"))
include(joinpath(@__DIR__, "corollary4.jl"))
include(joinpath(@__DIR__, "proposition3.jl"))

"""
    paper_report(io=stdout; save_results=false, full_search=false, n_max=8) -> NamedTuple

Run every bounded/default reproducible check for Budaghyan–Carlet–Leander (2009)
and print a structured report. The §2.1 linear-dependence search runs only when
`full_search=true`. Returns a NamedTuple of per-claim results.
"""
function paper_report(io::IO = stdout; save_results::Bool = false, full_search::Bool = false, n_max::Integer = 8)
    print_header(io)
    println(io, "Julia $(VERSION) — reproduction scope: exact / bounded / not-executed labelled per claim.")

    r_t1  = theorem1_report(io; n_max = 6, save_results)
    r_p1  = proposition1_report(io; n = 5, save_results)
    r_c1  = corollary1_report(io; n_max, save_results)
    r_p2  = proposition2_report(io; m = 3, save_results)
    r_t2  = theorem2_report(io; save_results)
    r_c2  = corollary2_report(io; save_results)
    r_s21 = section2_1_examples(io; save_results)
    r_t3  = theorem3_report(io; n = 7, save_results)
    r_c3  = corollary3_report(io; n = 7, save_results)
    r_c4  = corollary4_report(io; save_results)          # headline Δ-rank 212
    r_p3  = proposition3_report(io; save_results)

    r_search = nothing
    if full_search
        r_search = dependence_search(io; n = 5, r = 1, save_results)
    else
        print_section("§2.1 linear-dependence search (skipped)", io)
        print_kv("run with", "full_search=true (opt-in, bounded)", io)
    end

    print_section("summary", io)
    print_check("Theorem 1 — ℓ_a conditions ⇒ F+f APN",           r_t1.all_ok, io)
    print_check("Proposition 1 — differentially-4 constructions", r_p1.all_ok, io)
    print_check("Corollary 1 — x³+tr(x⁹) APN, deg 2 (n=3:$n_max)", r_c1.all_apn && r_c1.all_deg2, io)
    print_check("Proposition 2 — F,G EA-equivalent (n=6)",         r_p2.all_ok, io)
    print_check("Theorem 2 — m|n generalization APN (n=4,8)",      r_t2.all_ok, io)
    print_check("Corollary 2 — F,F' APN, F'=F^{2^m}, Gold witness", r_c2.all_ok, io)
    print_check("§2.1 examples — x⁵+tr(x³), x⁹+tr(x³)",            r_s21.all_ok, io)
    print_check("Theorem 3 — CCZ-inequiv to Gold (n=7)",           r_t3.all_inequiv, io)
    print_check("Corollary 3 — EA-inequiv to power fns (n=7)",     r_c3.all_ok, io)
    print_check("Corollary 4 — Δ-rank 212 vs 338/436 (n=7)",       r_c4.all_ok, io)
    print_check("Proposition 3 — non-quadratic APN CCZ-equiv F",   r_p3.all_ok, io)

    println(io, "\n  [NOTE] Catalog-gap candidates (NOT written — separate agent owns catalog):")
    println(io, "         • n=7  x³+tr(x⁹)  (Δ-rank 212, CCZ-inequiv to all power maps)")
    println(io, "         • n=8  x⁹+tr(x³)  (CCZ-inequiv to power maps and to x³+tr(x⁹))")

    result = (;
        theorem1 = r_t1, proposition1 = r_p1, corollary1 = r_c1, proposition2 = r_p2,
        theorem2 = r_t2, corollary2 = r_c2, section2_1 = r_s21, theorem3 = r_t3,
        corollary3 = r_c3, corollary4 = r_c4, proposition3 = r_p3, search = r_search,
    )
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "report.toml"), "w") do fh
            println(fh, "# Budaghyan–Carlet–Leander (2009) aggregate report")
            println(fh, "corollary1_apn = $(r_c1.all_apn)")
            println(fh, "corollary4_delta_rank_212 = $(r_c4.delta_x3tr9 == 212)")
            println(fh, "theorem3_ccz_inequiv_gold = $(r_t3.all_inequiv)")
        end
    end
    return result
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
