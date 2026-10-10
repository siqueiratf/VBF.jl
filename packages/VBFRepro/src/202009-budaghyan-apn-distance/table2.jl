# Implements Table II (Section IV.E)
# Paper: Budaghyan, Carlet, Helleseth, Kaleyski (2020),
#        "On the Distance Between APN Functions", IEEE Trans. Inf. Theory
# Section: IV.E — Examples: Table II — Switching class representatives
#
# Pseudocode:
#   For each APN representative F:
#     m_F   = min_{β,b} |Π_F^β(b)|            (compute_m_F, via pi_multiset)
#     bound = ⌈m_F/3⌉ + 1                     (Corollary 2)
#     mss   = min |U| over all single shifts  (Section V; exhaustive, n ≤ 6)
# VBF API used: SBox, compute_m_F, lower_bound_distance, differential_uniformity,
#               gf_monomial_lut, load_apn_function (VBFCatalog)

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "section5.jl"))
using VBFCatalog

# Table II, monomial rows (n, label, m_F, lower bound, minimum single-shift distance).
const TABLE2_MONOMIALS = [
    (4, "x^3", 3, 3, 2, 2),
    (5, "x^3", 3, 15, 6, 8),
    (5, "x^5", 5, 15, 6, 8),
    (5, "x^15", 15, 9, 4, 10),
]

# Table II, n=6 row 1.1 (the Gold function; the other 13 n=6 rows are Edel–Pott
# polynomial representatives absent from the catalog — see README, catalog gap).
const TABLE2_N6 = [(6, "1.1 (x^3)", 3, 27, 10, 16)]

# Table II, n=7: the paper gives "7.1 → 54 / 19" (the inverse function) and
# "all others → 63 / 22". The minimum single-shift distance column is "?" in the
# paper, and Section V's bitmask solver is limited to n ≤ 6, so it stays absent.
const TABLE2_N7 = [
    ("n7_Inverse_x126", "7.1 (inverse x^126)", 54, 19),
    ("n7_Gold_x3", "x^3", 63, 22),
    ("n7_Gold_x5", "x^5", 63, 22),
    ("n7_Gold_x9", "x^9", 63, 22),
    ("n7_Kasami_x13", "x^13", 63, 22),
    ("n7_Kasami_x57", "x^57", 63, 22),
    ("n7_Welch_x11", "x^11", 63, 22),
    ("n7_Niho_x39", "x^39", 63, 22),
]

"""
    table2_row(F; single_shift) -> NamedTuple

One Table II row for `F`: `m_F`, the Corollary 2 lower bound, and (when
`single_shift`) the minimum single-shift distance of Section V.
"""
function table2_row(F::SBox{N,T}; single_shift::Bool = true) where {N,T}
    apn = differential_uniformity(F) == 2
    mF = compute_m_F(F)
    bd = lower_bound_distance(mF)
    mss = (single_shift && N ≤ 6) ? min_single_shift_distance(F).distance : -1
    (; apn, mF, bd, mss)
end

"""
    table2_report(; io, include_n7) -> NamedTuple

Table II: m_F, the Corollary 2 lower bound and the minimum single-shift distance
for switching-class representatives.

Covered: the monomial rows at n=4 and n=5 (which exhaust all CCZ-classes in those
dimensions), the n=6 Gold row (Edel–Pott 1.1), and the whole n=7 block from the
catalog. The n=6 rows 1.2 / 2.1–2.12 and the whole n=8 block need the Edel–Pott
polynomial representatives, which are not in the catalog (and whose "1.1, 2.4, …"
labels have no mapping in it) — see the README.

The n=7 block is **cheap** (about 0.01 s per function; an earlier version of the
report labelled it an "expensive search" and skipped it).
"""
function table2_report(; io::IO = stdout, include_n7::Bool = true)
    print_section("Table II — Switching class representatives: m_F, bounds, single-shift", io)
    println(io, "  n    F                     m_F   bound   min single-shift   match?")

    all_ok = true
    results = []

    for (n, label, e, exp_m, exp_bd, exp_mss) in vcat(TABLE2_MONOMIALS, TABLE2_N6)
        F = SBox{n}(gf_monomial_lut(n, e))
        r = table2_row(F)
        match = r.apn && r.mF == exp_m && r.bd == exp_bd && r.mss == exp_mss
        all_ok &= match
        marker = match ? "✓" : "✗ (exp m=$exp_m, bd=$exp_bd, mss=$exp_mss)"
        println(io, "  $n    $(rpad(label, 20))  $(rpad(r.mF, 4))  $(rpad(r.bd, 6))  $(rpad(r.mss, 17))  $marker")
        push!(results, (; n, label, r.mF, r.bd, r.mss, r.apn, match))
    end

    if include_n7
        for (name, label, exp_m, exp_bd) in TABLE2_N7
            F = load_apn_function(name)
            r = table2_row(F; single_shift = false)   # n=7 > 6: Section V solver n/a
            match = r.apn && r.mF == exp_m && r.bd == exp_bd
            all_ok &= match
            marker = match ? "✓" : "✗ (exp m=$exp_m, bd=$exp_bd)"
            println(io, "  7    $(rpad(label, 20))  $(rpad(r.mF, 4))  $(rpad(r.bd, 6))  $(rpad("? (paper)", 17))  $marker")
            push!(results, (; n = 7, label, r.mF, r.bd, mss = -1, r.apn, match))
        end
    end

    println(io)
    println(io, "  [MISSING] n=6 rows 1.2 and 2.1–2.12, and the whole n=8 block: the Edel–Pott")
    println(io, "            representatives from [16] are not in the APN catalog, and the")
    println(io, "            catalog carries no Edel–Pott \"1.1 / 2.4 / …\" labels to map them by.")

    print_check("Table II: every reproduced row matches the paper", all_ok, io)
    (; all_ok, results)
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    table2_report()
end
