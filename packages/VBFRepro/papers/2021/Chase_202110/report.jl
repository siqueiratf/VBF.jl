# Aggregate report for Chase & Lisoněk (2021) reproduction.
# Paper: Chase, Lisoněk (2021), "Construction of APN permutations via Walsh
#        zero spaces"
# Section: General — aggregate report driver
#
# VBF API used: (delegated to included files)

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "proposition2_2.jl"))
include(joinpath(@__DIR__, "proposition3_1.jl"))
include(joinpath(@__DIR__, "definition3_2.jl"))
include(joinpath(@__DIR__, "proposition4_1.jl"))
include(joinpath(@__DIR__, "proposition4_2.jl"))
include(joinpath(@__DIR__, "proposition4_3.jl"))
include(joinpath(@__DIR__, "section4_coverage.jl"))
include(joinpath(@__DIR__, "proposition5_1.jl"))
include(joinpath(@__DIR__, "proposition5_2.jl"))
include(joinpath(@__DIR__, "proposition5_3.jl"))
include(joinpath(@__DIR__, "section6_1.jl"))
include(joinpath(@__DIR__, "section6_2.jl"))

"""
    paper_report(io; seed, sample_size, full_search) -> nothing

Reproduction scope:
  - Prop 2.2      — exact: permutation construction; CCZ verified at n=5,
                    by construction + invariants at n=7.
  - Prop 3.1      — exact: exhaustive LAT comparison at n=5, 7, 9.
  - Def 3.2-Cor 3.6 — exact: predicates + exhaustive 2-dim search n=5, 7, 9
                    (the paper's full range n ≤ 17 with full_search=true).
  - Prop 4.1-4.3  — exact: all spaces checked against actual Walsh zeros.
  - Sec 4 coverage — exact for n=3, 5 (cross-validated LAT subspace search
                    vs Prop 3.1 stratified enumeration), n=7 and n=9
                    (stratified enumeration; ~30 s at n=9).
  - Prop 5.1-5.3  — exact at n=3 / exhaustive 5.1 at n=9; 5.2, 5.3 sampled
                    with fixed seed at n=9.
  - Sec 6.1       — exact: 64 WZ spaces of x^3 on F_32, 3 EA classes.
  - Sec 6.2       — bounded demo: APN permutations of degrees {2, 4, 5} on
                    F_512; degree-4 EA-inequivalence via degree invariant.
"""
function paper_report(
    io::IO = stdout;
    seed::Int = 42,
    sample_size::Int = 12,
    full_search::Bool = false,
)
    paper_banner(io)
    proposition2_2_report(io; n = 5, i = 1)
    proposition2_2_report(io; n = 7, i = 1)
    proposition3_1_report(io; n = 5, i = 1)
    proposition3_1_report(io; n = 5, i = 2)
    proposition3_1_report(io; n = 7, i = 1)
    proposition3_1_report(io; n = 9, i = 1)
    definition3_2_report(io; n = 5, i = 1)
    definition3_2_report(io; n = 7, i = 1)
    definition3_2_report(io; n = 9, i = 1)
    definition3_2_report(io; n = 9, i = 2)
    if full_search
        definition3_2_report(io; n = 11, i = 1)
        definition3_2_report(io; n = 13, i = 1)
        definition3_2_report(io; n = 15, i = 1)
        # n = 17 has no canonical modulus in VBF; x^17 + x^3 + 1 is primitive.
        definition3_2_report(io; n = 17, i = 1, modulus = (1 << 17) | (1 << 3) | 1)
    end
    proposition4_1_report(io; n = 5, i = 1)
    proposition4_1_report(io; n = 9, i = 1)
    proposition4_2_report(io; n = 3, i = 1)
    proposition4_2_report(io; n = 9, i = 1)
    proposition4_3_report(io; n = 5, i = 1)
    proposition4_3_report(io; n = 9, i = 1)
    section4_coverage_report(io; n = 3, i = 1)
    section4_coverage_report(io; n = 5, i = 1)
    section4_coverage_report(io; n = 7, i = 1, enumerate = :stratified)
    section4_coverage_report(io; n = 9, i = 1, enumerate = :stratified)
    if full_search
        section4_coverage_report(io; n = 7, i = 2, enumerate = :stratified)
        section4_coverage_report(io; n = 7, i = 3, enumerate = :stratified)
        section4_coverage_report(io; n = 9, i = 2, enumerate = :stratified)
    end
    proposition5_1_report(io; n = 3, i = 1)
    proposition5_1_report(io; n = 9, i = 1)
    proposition5_2_report(io; n = 9, i = 1, seed = seed)
    proposition5_3_report(io; n = 9, i = 1, seed = seed)
    section6_1_report(io)
    section6_2_report(io; samples = sample_size, seed = seed)
    return nothing
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report(;
        seed = parse(Int, get(ENV, "CHASE_SEED", "42")),
        sample_size = parse(Int, get(ENV, "CHASE_SAMPLES", "12")),
        full_search = lowercase(get(ENV, "CHASE_FULL", "false")) == "true",
    )
end
