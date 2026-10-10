# Aggregate report for Canteaut–Couvreur–Perrin (2022) reproduction.
# Paper: Canteaut, Couvreur, Perrin (2022),
#        "Recovering or Testing Extended-Affine Equivalence"
# Section: General — aggregate report driver
#
# VBF API used: (delegated to included files)

using Dates

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "proposition14.jl"))
include(joinpath(@__DIR__, "section3_2.jl"))
include(joinpath(@__DIR__, "proposition18.jl"))
include(joinpath(@__DIR__, "proposition22.jl"))
include(joinpath(@__DIR__, "corollary24.jl"))
include(joinpath(@__DIR__, "proposition25.jl"))
include(joinpath(@__DIR__, "algorithm1.jl"))
include(joinpath(@__DIR__, "proposition35_36.jl"))
include(joinpath(@__DIR__, "section4_3.jl"))
include(joinpath(@__DIR__, "section4_4.jl"))
include(joinpath(@__DIR__, "section4_5.jl"))

"""
    paper_report(io; n_values, verify_min_ea) -> NamedTuple

Aggregate report for Canteaut–Couvreur–Perrin (2022).
Prints structured results for all reproducible claims.

Reproduction scope:
  - Prop 14 + Cor 15 — exact: derivative identities (Gold + multirank quadratic)
  - Prop 16 (Sec 3.2) — exact: Jac_lin chain rule for EA-equivalent functions
  - Prop 18 (Def 17) — exact: QAM matrix H = MᵀC_P M vs Jac_lin (Gold, κ)
  - Prop 22 + Rem 23 — exact: rank distribution ↔ DDT distribution
  - Cor 24 — exact: APN ⟺ Jac_lin rank n-1
  - Prop 25 / Table 2 — exact: rank bounds of systems (6)/(8), s = 1, 2, 3
  - Algorithm 1 — exact: EA-recovery at n=5 (s=3), n=7 and n=9 (s=2)
  - Props 35–36 + Lemma 34 — exact: ortho-derivative vs Jac_lin
  - Section 4.3 — exact: CCZ-class of κ (222 spaces, 8 spectra, 4 affine /
    2 EA permutation classes, butterflies, 3-twist structure)
  - Section 4.4 / Tables 6–7 — exact: entry-by-entry (min-#EA column for κ
    only; the other 12 sweeps ≈ 25–30 min, opt-in via verify_min_ea)
  - Tables 3–4 (running times of the authors' Sage implementation) — SKIPPED
    (hardware-specific timings, not mathematical claims; our own timings are
    printed by algorithm1_report)
  - Section 4.5 — bounded validation of the available 21,102-member corpus;
    full spectrum/signature scan is an explicit section4_5 Make target
"""
function paper_report(
    io::IO = stdout;
    n_values::Vector{Int} = [5, 6],
    verify_min_ea::Bool = false,
)
    print_header(io)
    println(io, "  Julia: ", VERSION)
    println(io, "  Date:  ", Dates.today())

    r_p14 = proposition14_report(; io, n_values)
    r_p16 = section3_2_report(; io, n_values)
    r_p18 = proposition18_report(; io)
    r_p22 = proposition22_report(; io, n_values)
    r_c24 = corollary24_report(; io, n_values)
    r_p25 = proposition25_report(; io)
    r_alg1 = algorithm1_report(; io)
    r_p35 = proposition35_36_report(; io)
    r_s43 = section4_3_report(; io)
    r_s44 = section4_4_report(; io, verify_min_ea)
    r_s45 = section4_5_report(; limit=16, io)

    print_section("Summary", io)
    print_check("Prop 14 + Cor 15: derivative identities of Jac_lin", r_p14.all_ok, io)
    print_check("Prop 16: Jac_lin chain rule for EA-equivalent functions", r_p16.all_ok, io)
    print_check("Prop 18: QAM matrix ↔ Jac_lin correspondence", r_p18.all_ok, io)
    print_check("Prop 22: rank distribution ↔ DDT distribution", r_p22.all_ok, io)
    print_check("Cor 24: APN ⟺ Jac_lin rank = n-1", r_c24.all_ok, io)
    print_check("Prop 25 / Table 2: linear system rank bounds", r_p25.all_ok, io)
    print_check("Algorithm 1: EA-recovery at n=5, 7, 9", r_alg1.all_ok, io)
    print_check("Props 35–36: ortho-derivative vs Jac_lin", r_p35.all_ok, io)
    print_check("Section 4.3: CCZ-class of the Kim mapping", r_s43.all_ok, io)
    print_check("Section 4.4: Tables 6–7 and catalog EA-partition", r_s44.all_ok, io)

    overall = r_p14.all_ok && r_p16.all_ok && r_p18.all_ok && r_p22.all_ok &&
              r_c24.all_ok && r_p25.all_ok && r_alg1.all_ok && r_p35.all_ok &&
              r_s43.all_ok && r_s44.all_ok
    print_check("Overall implemented bounded checks (see individual scopes)", overall, io)

    return (;
        proposition14 = r_p14,
        proposition16 = r_p16,
        proposition18 = r_p18,
        proposition22 = r_p22,
        corollary24 = r_c24,
        proposition25 = r_p25,
        algorithm1 = r_alg1,
        proposition35_36 = r_p35,
        section4_3 = r_s43,
        section4_4 = r_s44,
        section4_5 = r_s45,
        overall,
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
