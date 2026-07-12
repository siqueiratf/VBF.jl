# Implements Section 5.1 — Searching and classifying complete case (n,m)=(8,2)
# Paper: Ichanska, Berg, Kaleyski, Yu (2024/2025), "Pushing the QAM method for finding APN functions further"
# Section: 5.1 — New APN function (Table 5), ODDS vs Table 11
#
# Pseudocode:
#   1. Build the new APN function (Table 5): F(x) = a^170*x^192 + a^170*x^144 + a^85*x^48
#                                                   + x^36 + a^170*x^24 + a^170*x^18 + x^12 + x^6
#   2. Verify: APN (du=2), ODDS = [0^38196, 2^22008, 4^4608, 6^456, 8^12], NL=112
#   3. Load Gold x^3 and x^9 as known comparison functions (from catalog)
#   4. Verify new function's ODDS ≠ Gold ODDS → CCZ-inequivalent
#   Note: Full 27-class classification requires Simon-Berg thesis data (not available).
# VBF API used: polynomial_to_lut, conway_polynomial, SBox, differential_uniformity,
#               ortho_derivative, differential_spectrum, sorted_pairs, absolute_walsh_spectrum

include(joinpath(@__DIR__, "helpers.jl"))
using VBFCatalog

const _N8_MOD = conway_polynomial(8)

"""
    new_function_n8_m2() -> SBox{8}

The new APN function discovered in dimension 8 (Table 5, Section 5.1):
  F(x) = a^170 x^192 + a^170 x^144 + a^85 x^48 + x^36 + a^170 x^24 + a^170 x^18 + x^12 + x^6
over F₂⁸ with Conway polynomial 285 (a = primitive element = 2).
"""
function new_function_n8_m2()
    poly = "a^170*X^192 + a^170*X^144 + a^85*X^48 + X^36 + a^170*X^24 + a^170*X^18 + X^12 + X^6"
    SBox{8}(polynomial_to_lut(poly, 8, _N8_MOD))
end

"""
    expected_odds_new() -> Dict{Int,Int}

Expected ODDS for the new function (Table 11, index 10):
[0^38196, 2^22008, 4^4608, 6^456, 8^12]
"""
expected_odds_new() = Dict(0 => 38196, 2 => 22008, 4 => 4608, 6 => 456, 8 => 12)

function section5_1_report(io::IO = stdout)
    print_section(io, "Section 5.1: New APN function in dimension 8 (Table 5)")

    F = new_function_n8_m2()
    du = differential_uniformity(F)
    print_kv(io, "F", "a^170·x^192 + a^170·x^144 + a^85·x^48 + x^36 + a^170·x^24 + a^170·x^18 + x^12 + x^6")
    print_kv(io, "field n", 8)
    print_kv(io, "Conway polynomial", _N8_MOD)
    print_check(io, "APN (differential_uniformity = 2)", du == 2)

    ds = odds(F)
    exp = expected_odds_new()
    odds_match = all(ds.counts[k] == v for (k,v) in exp) && length(ds.counts) == length(exp)
    print_check(io, "ODDS = [0^38196, 2^22008, 4^4608, 6^456, 8^12] (Table 11, index 10)", odds_match)
    print_kv(io, "ODDS", join(["$k^$(ds.counts[k])" for (k,_) in sort(collect(exp))], ", "))

    ws = absolute_walsh_spectrum(F)
    max_w = maximum(keys(ws.counts))
    nl = (1 << 7) - max_w ÷ 2
    print_check(io, "Nonlinearity = 112 (Table 5)", nl == 112)
    print_kv(io, "NL", nl)

    # Compare ODDS with known Gold functions from catalog
    println(io)
    println(io, "  Comparison with Gold x^3 over F₂⁸ (from catalog):")
    db = load_catalog()
    r3 = find_function(db; canonical_name = "n8_Gold_x3")
    gold3 = load_sbox(db, r3.id)
    ds_gold3 = odds(gold3)
    close(db)
    print_check(io, "ODDS(new) ≠ ODDS(Gold x^3) → CCZ-inequivalent",
                ds.counts != ds_gold3.counts)

    println(io)
    print_kv(io, "Note on full 27-class classification",
             "Requires Simon-Berg thesis data (not available locally). " *
             "Table 10 lists 27 CCZ-class representatives; Table 11 lists their ODDS. " *
             "All 196863 found APN functions verified pairwise CCZ-inequivalent via ODDS.")
    print_kv(io, "Γ-rank = 14034", "out of scope (needs Magma)")
    print_kv(io, "Δ-rank = 438",   "out of scope (n=8 needs ~512 MB — not supported in VBF.jl)")
    print_kv(io, "|M(G_F)| = 3072","out of scope (needs Magma)")
    print_kv(io, "completeness", "exact for new function; full 27-class table requires Simon-Berg repo")
end

if abspath(PROGRAM_FILE) == @__FILE__
    section5_1_report()
end
