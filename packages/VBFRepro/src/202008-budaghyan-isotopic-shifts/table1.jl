# Implements Table I — CCZ-inequivalent quadratic APN polynomials over GF(2^9).
# Paper: Budaghyan et al. (2020), "Constructing APN Functions Through Isotopic Shifts",
#        IEEE Trans. Inf. Theory 66(8), pp. 5299–5309. DOI: 10.1109/TIT.2020.2974471
# Section: VII-B (Table I)
#
# Pseudocode:
#   1. Build all 8 rows of Table I over GF(2^9), modulus x⁹+x⁴+1, ζ primitive:
#        1  x³                            (Gold)
#        2  x⁵                            (Gold)
#        3  x¹⁷                           (Gold)
#        4  Tr₁⁹(x⁹) + x³                 [6]
#        5  Tr₃⁹(x¹⁸ + x⁹) + x³           [7]
#        6  Tr₃⁹(x³⁶ + x¹⁸) + x³          [7]
#        7  x³ + x¹⁰ + ζ⁴³⁸x¹³⁶           Edel–Pott 8.1
#        8  ζ³³⁷x¹²⁹ + ζ⁴²⁴x⁶⁶ + ζ²x¹⁷ + ζx¹⁰ + ζ³⁴x³   (new, Theorem VI.3)
#   2. Check every row is APN and quadratic.
#   3. Compute apn_ea_mugshot of each row; check all 8 are pairwise distinct.
#      Distinct mugshot ⟹ EA-inequivalent; all 8 rows are quadratic APN, and for
#      quadratic APN functions EA-equivalence coincides with CCZ-equivalence
#      (Yoshiara), so distinctness certifies the paper's CCZ-inequivalence claim.
#      The converse is NOT used: equal mugshots would prove nothing.
#   4. The Γ-rank column of Table I is not reproducible here (VBF's design_ranks
#      throws for n > 7), and is not needed: the mugshot already separates all 8.
# VBF API used: gold_apn, gf_trace, gf_relative_trace, terms_to_lut,
#               apn_ea_mugshot, algebraic_degree, differential_uniformity

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "section6.jl"))
using Dates
using VBFCatalog

"""
    table1_entries(; modulus) -> Vector{NamedTuple}

All 8 rows of the paper's Table I, built from the paper's own expressions over
GF(2⁹).  Rows 1–7 are the known quadratic APN classes; row 8 is the new function
of Theorem VI.3, built as the isotopic shift G_{1,L} — not transcribed from the
polynomial ([`section6_check_theoremVI3`](@ref) checks the two agree).
"""
function table1_entries(; modulus::Int = primitive_polynomial(9))
    n = 9
    z = primitive_element(n; modulus = modulus)
    ζ(t) = gf_pow(z, t, n; modulus = modulus)
    pow(x, e) = gf_pow(x, e, n; modulus = modulus)
    N = 1 << n

    rows = NamedTuple[]

    for (label, k) in (("1  x³", 1), ("2  x⁵", 2), ("3  x¹⁷", 4))
        push!(rows, (; label, source = "Gold", F = gold_apn(n, k; modulus = modulus)))
    end

    push!(rows, (; label = "4  Tr₁⁹(x⁹) + x³", source = "[6]",
        F = SBox{n}([
            gf_trace(pow(x, 9), n; modulus = modulus) ⊻ pow(x, 3) for x in 0:N-1
        ])))

    push!(rows, (; label = "5  Tr₃⁹(x¹⁸+x⁹) + x³", source = "[7]",
        F = SBox{n}([
            gf_relative_trace(pow(x, 18) ⊻ pow(x, 9), n, 3; modulus = modulus) ⊻ pow(x, 3)
            for x in 0:N-1
        ])))

    push!(rows, (; label = "6  Tr₃⁹(x³⁶+x¹⁸) + x³", source = "[7]",
        F = SBox{n}([
            gf_relative_trace(pow(x, 36) ⊻ pow(x, 18), n, 3; modulus = modulus) ⊻ pow(x, 3)
            for x in 0:N-1
        ])))

    push!(rows, (; label = "7  x³ + x¹⁰ + ζ⁴³⁸x¹³⁶", source = "Edel–Pott 8.1",
        F = SBox{n}(terms_to_lut([(1, 3), (1, 10), (ζ(438), 136)], n, modulus))))

    push!(rows, (; label = "8  NEW G_{1,L}, [ζ⁴²⁴,ζ,ζ³⁴]", source = "Theorem VI.3",
        F = section6_build_theorem_vi3_apn(
            section6_theorem_vi3_parameters(; modulus = modulus))))

    [(;
        r.label,
        r.source,
        r.F,
        apn = differential_uniformity(r.F) == 2,
        quadratic = algebraic_degree(r.F) == 2,
        mugshot = apn_ea_mugshot(r.F),
    ) for r in rows]
end

"""
    table1_check(; io) -> NamedTuple

Verify all 8 Table I entries are APN, quadratic, and pairwise EA-inequivalent
(distinct `apn_ea_mugshot`) — hence pairwise CCZ-inequivalent, since for
quadratic APN functions EA- and CCZ-equivalence coincide (Yoshiara).
"""
function table1_check(; io::IO = devnull)
    entries = table1_entries()

    all_apn = all(e.apn for e in entries)
    all_quadratic = all(e.quadratic for e in entries)
    mugshots = [e.mugshot for e in entries]
    n_distinct = length(unique(mugshots))
    all_distinct = n_distinct == length(mugshots)
    collisions = [
        (entries[i].label, entries[j].label)
        for i in 1:length(entries) for j in (i+1):length(entries)
        if mugshots[i] == mugshots[j]
    ]

    print_section(io, "Table I — CCZ-inequivalent quadratic APN functions over GF(2⁹)")
    print_kv(io, "entries built from the paper's expressions", length(entries))
    for e in entries
        print_kv(io, "  $(e.label)", "($(e.source)) APN=$(e.apn) deg2=$(e.quadratic)")
    end
    print_check(io, "all 8 entries are APN", all_apn)
    print_check(io, "all 8 entries are quadratic (so EA = CCZ, Yoshiara)", all_quadratic)
    print_check(io, "all 8 mugshots distinct → pairwise CCZ-inequivalent", all_distinct)
    print_kv(io, "distinct mugshots", "$n_distinct / $(length(mugshots))")
    print_kv(io, "collisions", isempty(collisions) ? "none" : collisions)
    print_kv(io, "note",
        "Table I has 8 rows = 7 known classes + 1 new (Theorem VI.3). The Γ-rank " *
        "column is not reproduced: VBF's design_ranks throws for n > 7. It is not " *
        "needed — the ortho-derivative mugshot already separates all 8 rows.")

    (; all_apn, all_quadratic, all_distinct, n_distinct, collisions,
       n_entries = length(entries))
end

function table1_report(io::IO = stdout)
    print_section(io, "Table I: CCZ-inequivalent Quadratic APN Functions over GF(2^9)")
    table1_check(; io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    using Dates
    table1_report()
end
