# Implements paper_report() for Li & Wang (2014).
# Paper: Li, Wang (2014), "Constructing Differentially 4-Uniform Permutations over
#        GF(2^{2m}) from Quadratic APN Permutations over GF(2^{2m+1})",
#        Designs, Codes and Cryptography 72:249–264
# Section: Report driver — calls all claim reports
#
# VBF API used: (see individual files)

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "theorem2.jl"))
include(joinpath(@__DIR__, "theorem4.jl"))
include(joinpath(@__DIR__, "proposition1.jl"))
include(joinpath(@__DIR__, "proposition2.jl"))
include(joinpath(@__DIR__, "theorem5.jl"))
include(joinpath(@__DIR__, "theorem6.jl"))
include(joinpath(@__DIR__, "remark3.jl"))

"""
    paper_report(; full_search=false, io=stdout)

Top-level report for Li & Wang (2014).
Prints header, field params, Julia version, date, reproduction scope, then
runs all claim checks.

Scope:
  Exact:   Theorems 2,3,4,5,6; Propositions 1,2; Remark 2; Remark 3 Walsh spectra;
           RDF(4) sets for EA-inequivalence (n=8)
  Bounded: Remark 3 n=8 pairwise CCZ (opt-in via full_search=true)
  Not run: n>=14 computations; full CCZ sweep vs all power mappings
"""
function paper_report(; full_search::Bool = false, io::IO = stdout)
    print_header(io)
    println(io, "Julia version: $(VERSION)")
    println(io)
    println(io, "Reproduction scope:")
    println(io, "  EXACT:   Theorems 2,3,4,5,6; Props 1,2; Remark 2; Walsh spectra; RDF sets")
    println(io, "  BOUNDED: Remark 3 n=8 CCZ (full_search=true to enable)")
    println(io, "  NOT RUN: n>=14; exhaustive CCZ vs all power mappings")

    theorem2_report(; io)
    theorem4_report(; io)
    proposition1_report(; io)
    proposition2_report(; io)
    theorem5_report(; io)
    theorem6_report(; io)
    remark3_report(; full_search, io)

    println(io)
    println(io, "-" ^ 72)
    println(io, "Report complete.")
end

if abspath(PROGRAM_FILE) == @__FILE__
    full_search = get(ENV, "LI_201408_FULL_SEARCH", "false") == "true"
    paper_report(; full_search)
end
