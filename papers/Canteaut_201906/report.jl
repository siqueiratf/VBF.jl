# Aggregate report for Canteaut, Perrin, Tian (2019) reproduction.
# Paper: Canteaut, Perrin, Tian (2019),
#        "If a Generalised Butterfly is APN then it Operates on 6 Bits"
# Section: General — aggregate report driver
#
# VBF API used: (delegated to included files)

using Dates

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "lemma1.jl"))
include(joinpath(@__DIR__, "proposition3.jl"))
include(joinpath(@__DIR__, "proposition5.jl"))
include(joinpath(@__DIR__, "proposition6.jl"))

"""
    paper_report(io; i) -> nothing

Aggregate report for Canteaut, Perrin, Tian (2019).
Prints structured results for all reproducible claims.

Reproduction scope:
  - Lemma 1     — exact: Tr(B^τ)=0 exhaustive n=3, spot-check n=5
  - Prop 3      — exact: APN ⟹ β∈{β₁,β₂} exhaustive n=3
  - Prop 5      — exact: APN ↔ refined_trace_cond exhaustive n=3
  - Prop 6+Thm1 — exact: n=5 exhaustive sweep finds zero APN butterflies
"""
function paper_report(io::IO = stdout; i::Int = 1)
    paper_banner(io)
    lemma1_report(io; n = 3, i)
    lemma1_report(io; n = 5, i)
    proposition3_report(io; n = 3, i)
    proposition5_report(io; n = 3, i)
    proposition6_report(io; i)
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
