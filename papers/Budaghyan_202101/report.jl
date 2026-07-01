# Top-level report for Budaghyan_202101.
# Paper: Budaghyan, Calderini, Carlet, Coulter, Villa (2021),
#        "Generalized Isotopic Shift Construction for APN Functions"
#
# Pseudocode:
#   1. Print banner (paper info, scope)
#   2. proposition2_1_report  (Remark 2.1 + Prop 2.1)
#   3. theorem3_1_report      (Theorem 3.1, Tables 1 & 3)
#   4. proposition3_2_report  (Prop 3.2, N_i invariant, Remark 3.2)
#   5. theorem3_2_report      (Theorem 3.2, nonlinear Gold shifts)
# VBF API used: print_banner, print_section, print_kv

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "proposition2_1.jl"))
include(joinpath(@__DIR__, "theorem3_1.jl"))
include(joinpath(@__DIR__, "proposition3_2.jl"))
include(joinpath(@__DIR__, "theorem3_2.jl"))

function paper_report(io::IO = stdout)
    paper_banner(io)
    print_kv(io, "Venue", "IEEE Trans. Inform. Theory (2021)")
    print_kv(io, "Authors", "Budaghyan, Calderini, Carlet, Coulter, Villa")
    println(io)
    print_kv(io, "Scope (exact)",
        "Remark 2.1; Theorem 3.1 + Table 1 (n=8) + Table 3 (n=9); " *
        "Proposition 3.2 N_i for new n=8 fn; Theorem 3.2 (5 families)")
    print_kv(io, "Scope (stated only)", "Proposition 2.1 (from [6]); Remark 3.2 fn 1.9")
    print_kv(io, "Out-of-scope", "CCZ-inequivalence (MAGMA); exhaustive F_{2^m}-polynomial search")
    println(io)

    proposition2_1_report(io)
    theorem3_1_report(io)
    proposition3_2_report(io)
    theorem3_2_report(io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
