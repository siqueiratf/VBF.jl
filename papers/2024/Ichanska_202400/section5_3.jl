# Implements Section 5.3 — Searching and classifying complete case (n,m)=(10,1)
# Paper: Ichanska, Berg, Kaleyski, Yu (2024/2025), "Pushing the QAM method for finding APN functions further"
# Section: 5.3 — Full search result: 577 quadratic APN functions → 3 CCZ classes
#
# Pseudocode:
#   1. Load Gold x^3 and x^9 from catalog (n=10, F₂ coefficients)
#   2. Construct third CCZ class: G(x) = x^3 + a^{-1}*Tr₁₀(a^3 * x^9) [reference 3]
#   3. Compute ODDS for all three; verify pairwise distinct
#   4. Verify all three are APN
# Note: The exhaustive search (577 functions) is out of scope; classification
#       into 3 CCZ classes is the paper's computational result (Section 5.3).
# VBF API used: differential_uniformity, ortho_derivative, differential_spectrum,
#               gf_pow, gf_mul, gf_inv, conway_polynomial, load_sbox, find_function

include(joinpath(@__DIR__, "helpers.jl"))
using VBFCatalog

const _N10_MOD = conway_polynomial(10)

function _gf_trace10(y::Int)
    n = 10
    acc = 0
    for _ in 0:n-1
        acc = xor(acc, y & 1)
        y = gf_pow(y, 2, n; modulus = _N10_MOD)
    end
    acc
end

"""
    third_ccz_class_n10() -> SBox{10}

Third CCZ class for (n,m)=(10,1): G(x) = x^3 + a^{-1}·Tr₁₀(a^3·x^9)
from Budaghyan, Carlet & Leander 2009 [reference 3 in the paper].
a = 2 (primitive element of F₂¹⁰ with Conway polynomial 1135).
"""
function third_ccz_class_n10()
    n = 10; mod = _N10_MOD
    a = 2
    ainv = gf_inv(a, n; modulus = mod)
    a3   = gf_pow(a, 3, n; modulus = mod)
    SBox{n}([begin
        x9 = gf_pow(x, 9, n; modulus = mod)
        tr = _gf_trace10(gf_mul(a3, x9, n; modulus = mod))
        xor(gf_pow(x, 3, n; modulus = mod), tr == 1 ? ainv : 0)
    end for x in 0:(1<<n)-1])
end

function section5_3_report(io::IO = stdout)
    print_section(io, "Section 5.3: (n,m)=(10,1) → three CCZ classes")
    print_kv(io, "field", "F₂¹⁰, Conway polynomial $(conway_polynomial(10))")
    print_kv(io, "main result", "577 quadratic APN functions (F₂ coefficients) → 3 CCZ classes")
    print_kv(io, "classes", "x^3, x^9, x^3 + a^{-1}Tr₁₀(a^3 x^9) [Budaghyan-Carlet-Leander 2009]")

    db = load_catalog()

    # Class 1: Gold x^3
    println(io, "\n  -- Class 1: Gold x^3 --")
    r3 = find_function(db; canonical_name = "n10_Gold_x3")
    F3 = load_sbox(db, r3.id)
    du3 = differential_uniformity(F3)
    ds3 = odds(F3)
    print_check(io, "APN (du=2)", du3 == 2)

    # Class 2: Gold x^9
    println(io, "\n  -- Class 2: Gold x^9 --")
    r9 = find_function(db; canonical_name = "n10_Gold_x9")
    F9 = load_sbox(db, r9.id)
    du9 = differential_uniformity(F9)
    ds9 = odds(F9)
    print_check(io, "APN (du=2)", du9 == 2)
    print_check(io, "ODDS(x^9) ≠ ODDS(x^3) → CCZ-inequivalent",
                ds9.counts != ds3.counts)

    # Class 3: third switching class
    println(io, "\n  -- Class 3: x^3 + a^{-1}Tr₁₀(a^3 x^9), a=2 --")
    G = third_ccz_class_n10()
    duG = differential_uniformity(G)
    dsG = odds(G)
    print_check(io, "APN (du=2)", duG == 2)
    print_check(io, "ODDS(G) ≠ ODDS(x^3) → CCZ-inequivalent", dsG.counts != ds3.counts)
    print_check(io, "ODDS(G) ≠ ODDS(x^9) → CCZ-inequivalent", dsG.counts != ds9.counts)

    println(io)
    print_kv(io, "completeness",
             "exact (3 representatives APN + pairwise CCZ-distinct via ODDS; " *
             "full 577-function search out of scope — months of compute)")
end

if abspath(PROGRAM_FILE) == @__FILE__
    section5_3_report()
end
