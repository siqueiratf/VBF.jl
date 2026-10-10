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
using VBFCatalog, VBFSearch, TOML, SHA

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

"""Verify the fixed EA graph witness to catalog Weng–Tan–Gong member 9.

The polynomial and both LUTs are mathematical data. Attribution to the 2013
publication depends on the catalog's source provenance; graph equivalence itself
is verified at every point independently of the equivalence search algorithm.
"""
function section5_1_prior_art()
    evidence = TOML.parsefile(joinpath(@__DIR__, "tests", "fixtures", "prior_art_ea.toml"))
    F = new_function_n8_m2()
    G = Int.(hex2bytes(evidence["target_lut_hex"]))
    Int.(F.lut) == Int.(hex2bytes(evidence["candidate_lut_hex"])) || error("candidate differs from witness fixture")
    bytes2hex(sha256(UInt8.(G))) == evidence["target_sha256"] || error("reference fixture digest mismatch")
    columns, constant = evidence["graph_map_columns"], evidence["graph_map_constant"]
    witness_verified = verify_ea_witness(Int.(F.lut), G, columns, constant)
    witness_verified || error("invalid prior-art EA graph witness")
    source_available = isfile(corpus_store_path("wengtangong2013_n8"))
    if source_available
        db = load_catalog()
        try
            current = corpus_function(db,"wengtangong2013_n8",9)
            Int.(current.lut) == G || error("catalog member changed; prior-art attribution must be re-audited")
        finally
            close(db)
        end
    end
    return (;witness_verified, reference="wengtangong2013_n8", member=9,
             attributed_bib_key="WengTanGong_201300", source_available,
             columns, constant, target_lut=G,
             conclusion="EA/CCZ equivalent to the stored reference; 2013 attribution follows catalog provenance")
end

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
    prior_art = section5_1_prior_art()
    print_check(io,"EA graph witness to Weng–Tan–Gong reference member 9 (all 256 points)", prior_art.witness_verified)
    print_kv(io,"reference source", prior_art.source_available ? "current corpus matches recorded LUT" : "corpus unavailable; stored reference LUT only")
    print_kv(io,"novelty", prior_art.conclusion)
    db = load_catalog()
    signatures = try
        [sorted_pairs(odds(load_sbox(db,"SimonBerg_GF4_n8_class_$k"))) for k in 1:27]
    finally
        close(db)
    end
    print_check(io,"27 catalog representatives have pairwise distinct ODDS", length(Set(signatures)) == 27)
    print_kv(io,"scope", "27 reference representatives; 196863 total functions are not pairwise inequivalent")
    print_kv(io, "published Γ-rank = 14034", "not computed in this bounded report; gamma_rank requires explicit n=8 opt-in and memory/time budgets")
    print_kv(io, "published Δ-rank = 438", "not computed in this bounded report; delta_rank requires explicit n=8 opt-in and memory/time budgets")
    print_kv(io, "|M(G_F)| = 3072","out of scope (needs Magma)")
    print_kv(io, "completeness", "exact for new function; 27 reference signatures and prior-art EA witness checked; exhaustive discovery not rerun")
end

if abspath(PROGRAM_FILE) == @__FILE__
    section5_1_report()
end
