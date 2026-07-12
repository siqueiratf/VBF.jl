# Implements Table III (Section IV.E)
# Paper: Budaghyan, Carlet, Helleseth, Kaleyski (2020),
#        "On the Distance Between APN Functions", IEEE Trans. Inf. Theory
# Section: IV.E — Table III: distance between the APN EA-representatives of F₂⁵
#          and the closest APN function
#
# Pseudocode:
#   For each EA-representative F over F₂⁵:
#     m_F         = min_{β,b} |Π_F^β(b)|                     (compute_m_F)
#     lower bound = ⌈m_F/3⌉ + 1                              (Corollary 2)
#     single-shift distance = min |U| over all v ∈ F₂ⁿ*      (Section V, exhaustive)
#     CCZ-class of the closest single-shift APN function      (are_ccz_equivalent)
# VBF API used: SBox, gf_monomial_lut, compute_m_F, lower_bound_distance,
#               differential_uniformity, are_ccz_equivalent

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "section5.jl"))

# APN functions over F₂⁵ fall into exactly three CCZ-classes; we name them by these
# canonical representatives. Table III's last column names the *EA*-representative of
# the class (it prints "x^7" and "x^11"), so its labels must be resolved through
# `ccz_class_n5` before comparison: x⁷ is CCZ-equivalent to x⁵, and x¹¹ to x³.
const N5_CCZ_REPS = (3, 5, 15)

"""
    ccz_class_n5(F) -> String

The CCZ-class of an APN `F` over `F₂⁵`, named by its canonical representative
`"x^3"`, `"x^5"` or `"x^15"` (`"?"` if it matches none, which cannot happen for an
APN function in this dimension — the classification is complete).
"""
function ccz_class_n5(F::SBox{5,T}) where {T}
    for cand in N5_CCZ_REPS
        are_ccz_equivalent(F, SBox{5}(gf_monomial_lut(5, cand))) && return "x^$cand"
    end
    "?"
end

# Table III, as printed: F, lower bound, actual distance, single-shift distance,
# number of shifts, CCZ-class of the resulting function.
#
# BCP-1 and BCP-2 (Budaghyan–Carlet–Pott, ref. [8]) are **not reproduced**: the n=5
# BCP EA-representatives exist neither in VBF (whose `bcp_apn` is the n=3k family)
# nor in the APN catalog. They are CCZ-equivalent to x³ / x⁵, so a CCZ-indexed
# catalog has no room for them — see the README's open questions.
const TABLE3_EXPECTED = [
    # exponent, lower bound, actual distance (paper), single-shift distance,
    # CCZ-class label as printed
    (3, 6, 8, 8, "x^5"),
    (5, 6, 8, 8, "x^3"),
    (7, 6, 10, 12, "x^7"),
    (11, 6, 10, 12, "x^11"),
    (15, 4, 10, 10, "x^15"),
]

const TABLE3_M_F = Dict(3 => 15, 5 => 15, 7 => 15, 11 => 15, 15 => 9)

"""
    table3_row(e; n=5) -> NamedTuple

One Table III row for the power function `x^e` over `F₂ⁿ`: `m_F`, the Corollary 2
lower bound, the exhaustive minimum single-shift distance, and the CCZ-class of the
closest **single-shift** APN function.

Caveat on the class column: the paper's last column describes the function found by
its filtered search over *arbitrary* (non-uniform) shifts, which for `x⁷` and `x¹¹`
sits at distance 10 while the single-shift optimum is 12 — a different function. The
two nevertheless land in the same CCZ-class in every row, so the comparison in
[`table3_report`](@ref) is still meaningful; it is simply not the *same witness* for
those two rows.
"""
function table3_row(e::Int; n::Int = 5)
    F = SBox{n}(gf_monomial_lut(n, e))
    apn = differential_uniformity(F) == 2
    mF = compute_m_F(F)
    bd = lower_bound_distance(mF)
    mss = min_single_shift_distance(F)

    # The APN function realising the minimum single-shift distance, and its class.
    G = apply_modifications(F, mss.U, fill(mss.v, length(mss.U)))
    ccz_class = ccz_class_n5(G)
    (; e, apn, mF, bd, distance = mss.distance, v = mss.v, U = mss.U,
        n_shifts = mss.n_shifts, ccz_class, own_class = ccz_class_n5(F), G)
end

"""
    table3_report(; io) -> NamedTuple

Table III for the power-function EA-representatives over F₂⁵.

Reproduced: the `m_F` / lower-bound column and the single-shift distance column
(both exhaustive). The "actual distance" column is the paper's own filtered
search over *arbitrary* (non-uniform) shift sets — quoted here, not recomputed.
The BCP-1 / BCP-2 rows are absent (see the constant above).
"""
function table3_report(; io::IO = stdout)
    print_section("Table III — F₂⁵ EA-representatives: distance to the closest APN function", io)
    println(io, "  F        m_F   lower bound   single-shift   CCZ class   match?")

    all_ok = true
    results = []
    for (e, exp_bd, exp_actual, exp_mss, exp_label) in TABLE3_EXPECTED
        r = table3_row(e)
        exp_m = TABLE3_M_F[e]
        # The paper labels the class by an EA-representative ("x^7", "x^11"); resolve it
        # to the canonical CCZ-representative before comparing.
        exp_class = ccz_class_n5(SBox{5}(gf_monomial_lut(5, parse(Int, exp_label[3:end]))))
        match = r.apn && r.mF == exp_m && r.bd == exp_bd &&
                r.distance == exp_mss && r.ccz_class == exp_class
        all_ok &= match
        marker = match ? "✓" : "✗ (exp m=$exp_m, bd=$exp_bd, ss=$exp_mss, class=$exp_class)"
        println(io, "  $(rpad("x^$e", 7))  $(rpad(r.mF, 4))  $(rpad(r.bd, 12))  " *
                    "$(rpad(r.distance, 13))  $(rpad("$(r.ccz_class) [$exp_label]", 14))  $marker")
        push!(results, (; e, r.mF, r.bd, r.distance, r.ccz_class, paper_label = exp_label, match))
    end

    println(io)
    println(io, "  [NOTE]    The CCZ-class column prints the canonical representative of the")
    println(io, "            class (x^3, x^5 or x^15 — the three CCZ-classes over F₂⁵) followed")
    println(io, "            by the paper's own label in brackets: the paper names the class by")
    println(io, "            an EA-representative, and x^7 ≅_CCZ x^5, x^11 ≅_CCZ x^3.")
    println(io, "  [QUOTED]  \"actual distance\" (8, 8, 10, 10, 10) and \"number of shifts\"")
    println(io, "            (1, 1, 10, 10, 10): the paper's filtered search over *non-uniform*")
    println(io, "            shift sets. Quoted, not recomputed — only the single-shift column")
    println(io, "            here is a computation. For x^7 and x^11 the paper's minimum-distance")
    println(io, "            function (d=10) is therefore not our single-shift one (d=12); both")
    println(io, "            land in the same CCZ-class.")
    println(io, "  [MISSING] BCP-1 / BCP-2 rows: the n=5 BCP EA-representatives of [8] are in")
    println(io, "            neither VBF nor the catalog (VBF's bcp_apn is the n=3k family).")

    print_check("Table III: m_F, lower bound, single-shift distance and CCZ class match", all_ok, io)
    (; all_ok, results)
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    table3_report()
end
