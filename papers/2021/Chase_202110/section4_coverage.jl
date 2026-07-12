# Implements the Section 4 coverage claim — the constructions of
# Propositions 4.1-4.3 plus the trivial spaces Z_a0, Z_0b cover ALL WZ
# spaces of Gold APN functions in odd dimensions ≤ 9 (verified by the
# authors with sboxU).
# Paper: Chase, Lisoněk (2021), "Construction of APN permutations via Walsh
#        zero spaces"
# Section: 4 — Constructions of some WZ spaces for Gold APN permutations
#
# Pseudocode:
#   constructed(n, i) = {Prop4.1(S) : S in the i-compatible catalog}
#                     ∪ {Prop4.2(ξ, μ)}            (if n = 3k, k odd)
#                     ∪ {Prop4.3(m, μ) : m | n}
#   enumerated(n, i)  = ALL n-dim WZ spaces, via
#     :lat        — generic subspace extraction from walsh_zeroes(f)
#                   (model-independent; feasible only for n ≤ 5), and/or
#     :stratified — enumerate_wz_spaces_gold (thickness-stratified exact
#                   enumeration built on the Prop 3.1 test; n ≤ 9)
#   claim: constructed == enumerated  (exact n = 3, 5, 7; n = 9 with
#   full_search=true — the stratified enumeration takes minutes there)
# VBF API used: gold_apn, walsh_zeroes, extract_linear_subspaces,
#   span_from_basis, primitive_polynomial

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "proposition4_1.jl"))
include(joinpath(@__DIR__, "proposition4_2.jl"))
include(joinpath(@__DIR__, "proposition4_3.jl"))

"""
    constructed_wz_spaces(n, i; modulus) -> Set{Vector{UInt32}}

All WZ spaces produced by the paper's constructions (field-packed spans,
deduplicated): Prop 4.1 over the i-compatible catalog (this includes the
trivial Z_a0 and Z_0b), Prop 4.2 (when n = 3k, k odd), Prop 4.3 for m | n.
"""
function constructed_wz_spaces(n::Int, i::Int; modulus::Int = primitive_polynomial(n))
    dual = gold_dual_table(n, i; modulus)
    tm = trace_mask_table(n; modulus)
    spans = Set{Vector{UInt32}}()
    for S in icompatible_catalog(n, i; modulus)
        push!(spans, proposition4_1_span(S, n, i; modulus, dual, tm))
    end
    if n % 3 == 0 && isodd(n ÷ 3)
        for xi in subfield_elements(n, 3; modulus), mu = 1:(1<<n)-1
            push!(spans, proposition4_2_span(xi, mu, n, i; modulus))
        end
    end
    for m in filter(m -> n % m == 0, 1:n), mu = 1:(1<<n)-1
        push!(spans, proposition4_3_span(m, mu, n, i; modulus))
    end
    spans
end

"""
    section4_coverage_build(n, i; modulus, enumerate) -> NamedTuple

Compare the constructed WZ spaces with the full enumeration of n-dim WZ
spaces. `enumerate` ∈ (:both, :lat, :stratified, :none):
  :lat        — generic subspace search on the actual Walsh zeros (n ≤ 5);
  :stratified — exact Prop 3.1-based enumeration (n ≤ 9);
  :both       — run both and cross-validate them against each other;
  :none       — generation side only (every constructed space is still
                verified to be a WZ space against the actual LAT).
"""
function section4_coverage_build(
    n::Int,
    i::Int;
    modulus::Int = primitive_polynomial(n),
    enumerate::Symbol = :both,
)
    F = gold_apn(n, i; modulus)
    tm = trace_mask_table(n; modulus)
    zset = Set(walsh_zeroes(F))
    constructed = constructed_wz_spaces(n, i; modulus)
    all_wz = all(z -> is_wz_space_lat(z, F, tm; zset), constructed)
    n_enumerated = -1
    covered = missing
    methods_agree = missing
    if enumerate in (:stratified, :both)
        strat = Set{Vector{UInt32}}(enumerate_wz_spaces_gold(n, i; modulus, tm))
        n_enumerated = length(strat)
        covered = constructed == strat
        if enumerate === :both
            bases = extract_linear_subspaces(walsh_zeroes(F), n; max_bits = 2 * n)
            lat_set = Set{Vector{UInt32}}(sort(span_from_basis(b)) for b in bases)
            strat_mask =
                Set{Vector{UInt32}}(to_mask_coords(z, tm, n) for z in strat)
            methods_agree = strat_mask == lat_set
        end
    elseif enumerate === :lat
        bases = extract_linear_subspaces(walsh_zeroes(F), n; max_bits = 2 * n)
        lat_set = Set{Vector{UInt32}}(sort(span_from_basis(b)) for b in bases)
        n_enumerated = length(lat_set)
        covered =
            Set{Vector{UInt32}}(to_mask_coords(z, tm, n) for z in constructed) ==
            lat_set
    end
    (; n, i, n_constructed = length(constructed), all_wz, n_enumerated,
       covered, methods_agree, enumerate)
end

function section4_coverage_report(io::IO = stdout; n::Int = 5, i::Int = 1, enumerate::Symbol = :both)
    r = section4_coverage_build(n, i; enumerate)
    print_section("Section 4 coverage — constructions give ALL WZ spaces, n=$n, i=$i", io)
    print_check(io, "every constructed space is a WZ space (actual LAT)", r.all_wz)
    if r.enumerate === :none
        print_kv(io, "completeness", "generation side only — enumeration skipped by default " *
                     "(run with full_search=true; the paper used sboxU here)")
    else
        print_check(
            io,
            "constructed set == all $(r.n_enumerated) n-dim WZ spaces",
            r.covered === true,
        )
        r.methods_agree !== missing && print_check(
            io,
            "stratified enumeration == generic LAT subspace search",
            r.methods_agree === true,
        )
        print_kv(io, "completeness", "exhaustive (method: $(r.enumerate))")
    end
    print_kv(io, "constructed distinct WZ spaces", r.n_constructed)
end

if abspath(PROGRAM_FILE) == @__FILE__
    section4_coverage_report(; n = 3, i = 1)
    section4_coverage_report(; n = 5, i = 1)
    section4_coverage_report(; n = 7, i = 1, enumerate = :stratified)
    section4_coverage_report(; n = 9, i = 1, enumerate = :none)
end
