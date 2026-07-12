# Aggregate report for Canteaut, Perrin, Tian (2019) reproduction.
# Paper: Canteaut, Perrin, Tian (2019),
#        "If a Generalised Butterfly is APN then it Operates on 6 Bits"
# Section: General — aggregate report driver
#
# VBF API used: (delegated to included files)

using Dates

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "equivalences.jl"))
include(joinpath(@__DIR__, "proposition1.jl"))
include(joinpath(@__DIR__, "proposition2.jl"))
include(joinpath(@__DIR__, "lemma1.jl"))
include(joinpath(@__DIR__, "proposition3.jl"))
include(joinpath(@__DIR__, "proposition4.jl"))
include(joinpath(@__DIR__, "proposition5.jl"))
include(joinpath(@__DIR__, "proposition6.jl"))

"""
    paper_report(io) -> nothing

Aggregate report for Canteaut, Perrin, Tian (2019).
Prints structured results for all reproducible claims, sweeping every i
with gcd(i,n)=1 for n=3 (i∈{1,2}) and n=5 (i∈{1,2,3,4}).

Reproduction scope:
  - Sec 2.2     — exact: Frobenius and β↔β′ affine-equivalence identities
  - Prop 1      — exact: Helleseth–Kholosha counts |S₀|,|S₁|,|S₃| + trace criterion
  - Prop 2      — exact: linearised-equation solution counts, all (U,V,C)
  - Lemma 1     — exact: Tr(B^τ)=0 exhaustive n=3, n=5
  - Prop 3      — exact: APN ⟹ β∈{β₁,β₂} exhaustive; α=1 never APN (DU ≥ 4)
  - Prop 4      — exact: APN ⟺ β∈{β₁,β₂} ∧ trace cond; bridge to Prop 5
  - Prop 5      — exact: APN ↔ refined_trace_cond
  - Prop 6+Thm1 — exact: n=5 exhaustive sweeps find zero APN butterflies
"""
function paper_report(io::IO = stdout)
    cases = ((3, 1), (3, 2), (5, 1), (5, 2), (5, 3), (5, 4))
    paper_banner(io)
    equivalences_report(io; cases)
    proposition1_report(io; cases)
    proposition2_report(io; cases)
    lemma1_report(io; cases)
    proposition3_report(io; cases)
    proposition4_report(io; cases)
    proposition5_report(io; cases)
    proposition6_report(io; i_n3 = (1, 2), i_n5 = (1, 2, 3, 4))
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
