# Implements Theorem 11 — the new non-quadratic APN function on F_2^6.
# Paper: Edel, Pott (2009), "A new almost perfect nonlinear function which is
#        not quadratic", Adv. Math. Commun. 3(1):59-81.
# Section: 3 — Dillon's switching construction (Theorem 11, eq. 9).
#
# Pseudocode:
#   1. Build the eq.(9) representative F (helpers.theorem11_function).
#   2. Assert F is APN (differential_uniformity == 2).
#   3. Assert algebraic_degree(F) == 3  — F is NOT quadratic.
#   4. Compute Γ-rank=1300, Δ-rank=152 (matches Table 6 entry 2.11).
#   5. Δ-rank 152 > 2^(n+1)=128 ⇒ F is not CCZ-crooked ⇒ not CCZ-quadratic
#      (Theorem 7). Hence a genuinely new (non-quadratic) CCZ class.
#   6. F shares the CCZ-invariant fingerprint (Γ,Δ,degree,Δ-spectrum,|Walsh|) of
#      the Table-5 2.11 representative → same class.
#   7. CCZ-inequivalent to Gold x^3 (power map): Γ-rank 1300 ≠ 1102, corroborated
#      by are_ccz_equivalent.
# VBF API used: differential_uniformity, algebraic_degree, gamma_rank,
#               delta_rank, ddt, absolute_walsh_spectrum, are_ccz_equivalent,
#               print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

# CCZ-invariant fingerprint used to place two functions in the same class.
function _ep_fingerprint(F)
    (; gamma = gamma_rank(F),
       delta = delta_rank(F),
       du = differential_uniformity(F),
       ddt_spectrum = sort(vec(ddt(F))),
       awt = absolute_walsh_spectrum(F))
end

"""
    theorem11_report(io = stdout; check_ccz = true, save_results = false) -> NamedTuple

Reproduce Theorem 11: the eq.(9) function is a new non-quadratic APN on
`GF(2⁶)`, degree 3, Γ/Δ-rank (1300, 152), not crooked (Theorem 7), and
CCZ-inequivalent to the power map `x³`.
"""
function theorem11_report(io::IO = stdout; check_ccz::Bool = true, save_results::Bool = false)
    print_section("Theorem 11 — new non-quadratic APN F on GF(2^6) (eq. 9)", io)
    F = theorem11_function()

    du   = differential_uniformity(F)
    deg  = algebraic_degree(F)
    g    = gamma_rank(F)
    d    = delta_rank(F)
    bound = 1 << (EP_N + 1)                       # 2^(n+1) = 128

    print_check("F is APN (Δ-uniformity=$du)", du == 2, io)
    print_check("F is NOT quadratic: algebraic degree = $deg (== 3)", deg == 3, io)
    print_check("Γ-rank = $g (Table 6 entry 2.11: 1300)", g == 1300, io)
    print_check("Δ-rank = $d (Table 6 entry 2.11: 152)", d == 152, io)
    print_check("Theorem 7: Δ-rank $d > 2^(n+1)=$bound ⇒ F is not CCZ-crooked " *
        "⇒ not CCZ-quadratic", d > bound, io)

    # Same CCZ class as the Table-5 2.11 representative (different formula).
    rep211 = only(r.sbox for r in edelpott_table5() if r.name == "2.11")
    same_class = _ep_fingerprint(F) == _ep_fingerprint(rep211)
    print_check("shares CCZ-invariant fingerprint of Table-5 rep 2.11 (same class)",
        same_class, io)

    # CCZ-inequivalence to the power map x^3 (Gold), via CCZ-invariant Γ-rank.
    gold = ep_gold_x3()
    g_gold = gamma_rank(gold)
    print_check("CCZ-inequivalent to power map x^3: Γ-rank $g ≠ $g_gold (invariant)",
        g != g_gold, io)
    ccz_gold = missing
    if check_ccz
        ccz_gold = are_ccz_equivalent(F, gold)
        print_check("are_ccz_equivalent(F, x^3) == false (direct CCP test)",
            ccz_gold == false, io)
    end
    print_kv("power-map exclusion (paper, Theorem 10)",
        "|M(G_F)| not divisible by 2^6-1=63 — MAGMA, see theorem10.jl", io)

    result = (; du, deg, gamma = g, delta = d, not_crooked = d > bound,
        same_class, ccz_to_gold = ccz_gold)
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "theorem11.toml"), "w") do f
            println(f, "# Edel–Pott (2009) Theorem 11 — new non-quadratic APN")
            println(f, "differential_uniformity = $du")
            println(f, "algebraic_degree = $deg")
            println(f, "gamma_rank = $g")
            println(f, "delta_rank = $d")
            println(f, "not_crooked = $(d > bound)")
            println(f, "same_class_as_table5_2_11 = $same_class")
        end
    end
    return result
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem11_report()
end
