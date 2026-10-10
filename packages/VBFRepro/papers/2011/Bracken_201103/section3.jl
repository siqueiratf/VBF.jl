# Implements Section 3 — Equivalence.
# Paper: Bracken, Byrne, Markin, McGuire (2011), "A Few More Quadratic APN Functions",
#        Cryptography and Communications 3:43–53
# Section: 3 — Equivalence (Tables 1, 2, 3)
#
# Pseudocode:
#   1. Instantiate the four subfamilies for n=6 (Table 2 small case).
#   2. For n=6, compute Δ-ranks; verify Family 1 differs from Families 7/8W/8.
#   3. For n=12 (Table 2 exact exponents from paper), verify APN only.
#      Δ-rank for n=12 is out-of-scope (requires a 2^24×2^24 matrix; VBF supports only n≤8 with explicit budgets).
#   4. Table 3 delta-rank values for n=12 are reproduced from the paper (loaded).
#
# VBF API used: SBox, differential_uniformity, delta_rank, gold_apn, kasami_apn

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "theorem1.jl"))


# ---------------------------------------------------------------------------
# Table 2 helpers — exact exponent/coefficient forms from the paper
# ---------------------------------------------------------------------------

"""
    table2_n6_instances() -> Vector{NamedTuple}

The four subfamily instances for n=6, k=2, s=1, u=2, v∈GF(4) chosen so that the
trinomial terms match the paper's explicit polynomial forms in Section 3.

Paper writes, for v∈GF(4):
ux³+vu⁵x¹⁰+vx¹⁷+u⁴x²⁴ (Family 8),
ux³+vx¹⁷+u⁴x²⁴ (8W),
ux³+vu⁵x¹⁰+u⁴x²⁴ (7),
ux³+u⁴x²⁴ (1).
For Family 8: v acts as both the v-term and w-term (paper uses a single coefficient).
"""
function table2_n6_instances()
    modulus = primitive_polynomial(6)
    v6 = subfield_elem(6, 2, 0; modulus)  # u^21, generator of GF(4)*
    [
        (; family = "1",  label = "n=6 Family 1  (v=0, w=0)", sbox = theorem1_sbox(2, 1, 0, 0; modulus)),
        (; family = "7",  label = "n=6 Family 7  (v=0, w≠0)", sbox = theorem1_sbox(2, 1, 0, 1; modulus)),
        (; family = "8W", label = "n=6 Family 8W (v≠0, w=0)", sbox = theorem1_sbox(2, 1, 1, 0; modulus)),
        # Family 8 uses independent v,w (two distinct GF(4)* elements) — a valid
        # Theorem 2.1 member, but NOT the paper's literal single-coefficient n=6
        # display form vu⁵x¹⁰+vx¹⁷, where one coefficient v feeds both terms.
        (; family = "8",  label = "n=6 Family 8  (v≠0, w≠0)", sbox = theorem1_sbox(2, 1, 1, 2; modulus)),
    ]
end


"""
    table2_n12_instances() -> Vector{NamedTuple}

Table 2 (paper): example functions for n=12, k=4, s=5.
Exact forms: u^16 x^768 + u x^33 [+x^257] [+u^290 x^544].
u=2 primitive; x^257 = 1·x^257 so v=u^0=1; u^290=u^17·u^273 so w=u^273∈GF(16).
"""
function table2_n12_instances()
    modulus = primitive_polynomial(12)
    # GF(16) in GF(2^12): norm = (2^12−1)/(2^4−1) = 4095/15 = 273
    v12 = 1                                           # v = u^0 = 1 ∈ GF(16)
    w12 = subfield_elem(12, 4, 1; modulus)           # w = u^273 ∈ GF(16)
    [
        (; family = "8",  label = "n=12 Family 8:  u^16 x^768 + u x^33 + x^257 + u^290 x^544",
           sbox = theorem1_sbox(4, 5, 1, 2; modulus)),
        (; family = "8W", label = "n=12 Family 8W: u^16 x^768 + u x^33 + x^257",
           sbox = theorem1_sbox(4, 5, 1, 0; modulus)),
        (; family = "7",  label = "n=12 Family 7:  u^16 x^768 + u x^33 + u^290 x^544",
           sbox = theorem1_sbox(4, 5, 0, 2; modulus)),
        (; family = "1",  label = "n=12 Family 1:  u^16 x^768 + u x^33",
           sbox = theorem1_sbox(4, 5, 0, 0; modulus)),
    ]
end


# ---------------------------------------------------------------------------
# Table 3 — delta-ranks (paper values, n=12; computed here for n=6 only)
# ---------------------------------------------------------------------------

# Reproduced from Table 3 of the paper (loaded values, original Magma computation).
const TABLE3_PAPER_DELTA_RANKS_N12 = Dict(
    "Gold x^3"          => 7550,
    "Gold x^33"         => 7550,
    "Kasami x^993"      => 62550,
    "Family 1"          => 7816,
    "Family 2"          => 7822,
    "Family 5"          => 7550,
    "Family 6"          => 7846,
    "Family 7"          => 7900,
    "Family 8W"         => 7900,
    "Family 8"          => 7900,
)


function section3_report(io::IO = stdout)
    print_section("Section 3 — Equivalence (CCZ-inequivalence evidence)", io)

    println(io, "  " * "!"^68)
    println(io, "  NOVELTY-GAP MARKER — read before trusting any 'NEW / CCZ-inequivalent' claim:")
    println(io, "    [computed] n=6 Δ-ranks (below) are computed here by VBF.jl.delta_rank.")
    println(io, "    [loaded]   n=12 Δ-ranks (Table 3) are TRANSCRIBED from the paper's")
    println(io, "               original Magma computation — NOT computed in this repo")
    println(io, "               (VBF.delta_rank supports n≤8 with explicit budgets; n=12 is a 2^24×2^24 matrix).")
    println(io, "    [UNVERIFIED] Family 7 vs Family 8W are NOT separated in this repo:")
    println(io, "               Δ-rank PROVABLY cannot split them (the paper reports EQUAL")
    println(io, "               Δ-ranks for 7/8W/8). A rigorous split needs Feulner canonical")
    println(io, "               form / automorphism group — out of scope for this reproduction.")
    println(io, "  " * "!"^68)

    # ── Table 2, n=6: APN check and Δ-rank distinguisher ───────────────────
    println(io, "  [computed] Table 2 (n=6, k=2, s=1): four subfamilies — APN check + Δ-rank")
    n6_cases   = table2_n6_instances()
    n6_dranks  = Dict{String,Int}()
    for c in n6_cases
        apn = differential_uniformity(c.sbox) == 2
        dr  = delta_rank(c.sbox)
        n6_dranks[c.family] = dr
        print_check(c.label * "  apn=" * string(apn) * "  Δ-rank=" * string(dr), apn, io)
    end
    println(io)

    # n=6: paper claims Family 1 ≠ others (CCZ-inequivalent at n=6)
    fam1_dr   = n6_dranks["1"]
    fam7_dr   = n6_dranks["7"]
    fam8w_dr  = n6_dranks["8W"]
    fam8_dr   = n6_dranks["8"]
    f1_differs = (fam1_dr != fam7_dr)
    print_check("n=6 Family 1 Δ-rank differs from Family 7 (expected)", f1_differs, io)

    # Gold x^3 for n=6
    gold6_dr = delta_rank(gold_apn(6, 1))
    print_kv("n=6 Gold x^3 Δ-rank", gold6_dr, io)
    print_check("n=6 Family 1 Δ-rank == Gold x^3 (equal invariant; equivalence unresolved)", fam1_dr == gold6_dr, io)
    println(io)

    # ── Table 2, n=12: APN check only ──────────────────────────────────────
    println(io, "  Table 2 (n=12, k=4, s=5): four subfamilies — APN check only")
    n12_cases = table2_n12_instances()
    for c in n12_cases
        apn = differential_uniformity(c.sbox) == 2
        print_check(c.label, apn, io)
    end
    println(io)

    # ── Table 3, n=12: loaded paper values ─────────────────────────────────
    println(io, "  [loaded] Table 3 (n=12): delta-ranks — from paper (Cannon–Nebe–Steel, Magma)")
    println(io, "  (Δ-rank for n=12 requires a 2^24×2^24 matrix; out-of-scope for VBF.jl.)")
    for (fam, dr) in sort(collect(TABLE3_PAPER_DELTA_RANKS_N12), by = x -> x[2])
        print_kv("  " * fam, dr, io)
    end
    println(io)

    # Verify loaded values encode the paper's inequivalence claims
    fam7_dr12  = TABLE3_PAPER_DELTA_RANKS_N12["Family 7"]
    fam8w_dr12 = TABLE3_PAPER_DELTA_RANKS_N12["Family 8W"]
    fam8_dr12  = TABLE3_PAPER_DELTA_RANKS_N12["Family 8"]
    fam1_dr12  = TABLE3_PAPER_DELTA_RANKS_N12["Family 1"]
    print_check("n=12 Families 7/8W/8 share Δ-rank (paper claim)",
                fam7_dr12 == fam8w_dr12 == fam8_dr12, io)
    print_check("n=12 Family 1 Δ-rank ≠ Family 7 (paper claim)",
                fam1_dr12 != fam7_dr12, io)
    print_check("n=12 Gold Δ-rank ≠ Family 7 (paper claim)",
                TABLE3_PAPER_DELTA_RANKS_N12["Gold x^3"] != fam7_dr12, io)
    print_kv("completeness",
             "n=6 Δ-ranks exhaustive; n=12 loaded (original Magma, Cannon–Nebe–Steel)", io)
end


if abspath(PROGRAM_FILE) == @__FILE__
    section3_report()
end
