# Implements Section 4: Equivalence relations and linear codes.
# Paper: Calderini (2020), "On the EA-classes of known APN functions in small dimensions"
# Section: 4 — Equivalence relations and linear codes
#
# Pseudocode:
#   1. C₁(F) (CCZ code, VBF ccz_matrix), C₂/C₃/C₄ (helpers.jl, paper-exact
#      column blocks — note VBF's ea_matrix mis-packs its y-columns and is
#      not used here).
#   2. Theorem 5 demos via weight enumerators (equivalent codes ⟹ equal WE):
#      equal WE for pairs the theorem says are code-equivalent, and an
#      UNEQUAL WE(C₂) proving Kim ≁EA Dillon at the code level.
#   3. Theorem 6: F₁ vs F₁⁻¹ — C₃ cannot separate them (codes equivalent,
#      equal WE), C₄ does (paper). The C₄ codes here are WE-isospectral for
#      every shift b (checked), so weight-type invariants provably cannot
#      certify the separation; it is certified function-side by the complete
#      affine-equivalence decision + the Theorem 6 "iff". Direct code
#      inequivalence testing still needs MAGMA / Leon's algorithm.
# VBF API used: ccz_matrix, dillon_apn_permutation, kim_apn, are_affine_equivalent,
#               is_permutation, compositional_inverse, random_affine_permutation

include(joinpath(@__DIR__, "helpers.jl"))
using VBFCatalog

"""
    verify_code_dimensions(F) -> NamedTuple

Verify that C₁..C₄ have the paper's dimensions:
C₁ (2n+1)×2ⁿ, C₂ (2n+1)×(2^{n+1}-1), C₃ (2n+1)×(2^{n+1}+2ⁿ-2),
C₄ (2n+1)×(2^{n+1}+2ⁿ-1) (permutations only).
"""
function verify_code_dimensions(F::SBox{N,T}) where {N,T}
    n_size = 1 << N
    expected_C1 = (2N + 1, n_size)
    expected_C2 = (2N + 1, 2n_size - 1)
    expected_C3 = (2N + 1, 3n_size - 2)
    expected_C4 = (2N + 1, 3n_size - 1)
    ok1 = size(ccz_matrix(F)) == expected_C1
    ok2 = size(c2_matrix(F)) == expected_C2
    ok3 = size(c3_matrix(F)) == expected_C3
    ok4 = is_permutation(F) ? size(c4_matrix(F)) == expected_C4 : false
    return (; ok1, ok2, ok3, ok4, expected_C1, expected_C2, expected_C3, expected_C4)
end

"""
    theorem5_demo(io) -> Bool

Theorem 5 exercised through weight enumerators:
- CCZ-equivalent pair (Kim, Dillon): equal WE(C₁).
- EA-inequivalent pair (Kim, Dillon): UNEQUAL WE(C₂) — a code-level *proof*
  that Kim ≁EA Dillon (algebraic degrees 2 vs 4 give the function-level proof).
- Permutation pair (Dillon, Dillon⁻¹): equal WE(C₃) — C₃(F) ≅ C₃(G) holds iff
  F is AE to G or G⁻¹, and Dillon IS affine-equivalent to its inverse.
"""
function theorem5_demo(io::IO = stdout)
    K = kim_apn()
    D = dillon_apn_permutation()
    Dinv = compositional_inverse(D)

    ok = true
    same_c1 = code_weight_enumerator(ccz_matrix(K)) == code_weight_enumerator(ccz_matrix(D))
    print_check(io, "WE(C₁(Kim)) == WE(C₁(Dillon))  [CCZ-equivalent pair]", same_c1)
    ok &= same_c1

    diff_c2 = code_weight_enumerator(c2_matrix(K)) != code_weight_enumerator(c2_matrix(D))
    print_check(io, "WE(C₂(Kim)) ≠ WE(C₂(Dillon))  [proves Kim ≁EA Dillon]", diff_c2)
    ok &= diff_c2

    same_c3 = code_weight_enumerator(c3_matrix(D)) == code_weight_enumerator(c3_matrix(Dinv))
    print_check(io, "WE(C₃(Dillon)) == WE(C₃(Dillon⁻¹))  [D AE D⁻¹ ⟹ C₃ equiv]", same_c3)
    ok &= same_c3
    return ok
end

"""
    theorem6_demo(io) -> Bool

Theorem 6 with the paper's actual F₁ (Section 5.1): F₁ is NOT affine-equivalent
to F₁⁻¹ (complete decision), yet C₃ cannot see it (F₁ IS AE to (F₁⁻¹)⁻¹, so the
C₃ codes are equivalent — equal WE confirms consistency). The new C₄ code
separates them per Theorem 6; the C₄ codes are however WE-isospectral for every
shift b, so the separation cannot be certified by weight enumerators — it
follows from the theorem's "iff" plus the function-level AE decision. A direct
code-equivalence computation requires MAGMA / Leon's algorithm.
"""
function theorem6_demo(io::IO = stdout)
    F1 = calderini_f1()
    F1inv = compositional_inverse(F1)

    ok = true
    apn1 = is_permutation(F1) && differential_uniformity(F1) == 2
    print_check(io, "F₁ is an APN permutation", apn1)
    ok &= apn1

    not_ae = !are_affine_equivalent(F1, F1inv)
    print_check(io, "F₁ NOT affine-equivalent to F₁⁻¹ (complete AE decision)", not_ae)
    ok &= not_ae

    dims = verify_code_dimensions(F1)
    print_check(io, "C₁(F₁) dims $(dims.expected_C1)", dims.ok1)
    print_check(io, "C₂(F₁) dims $(dims.expected_C2)", dims.ok2)
    print_check(io, "C₃(F₁) dims $(dims.expected_C3)", dims.ok3)
    print_check(io, "C₄(F₁) dims $(dims.expected_C4) (z over ALL of F₂ⁿ)", dims.ok4)
    ok &= dims.ok1 && dims.ok2 && dims.ok3 && dims.ok4

    same_c3 = code_weight_enumerator(c3_matrix(F1)) == code_weight_enumerator(c3_matrix(F1inv))
    print_check(io, "WE(C₃(F₁)) == WE(C₃(F₁⁻¹))  [C₃ can NOT separate F₁ from F₁⁻¹]", same_c3)
    ok &= same_c3

    w4 = code_weight_enumerator(c4_matrix(F1))
    n_size = 1 << inputbits(F1)
    all_iso = true
    for b = 0:(n_size - 1)
        lut = [F1inv.lut[x + 1] ⊻ typeof(F1inv.lut[1])(b) for x = 0:(n_size - 1)]
        all_iso &= code_weight_enumerator(c4_matrix(SBox{6}(lut))) == w4
    end
    print_check(
        io,
        "C₄(F₁) and C₄(F₁⁻¹+b) are WE-isospectral for ALL b (WE cannot certify)",
        all_iso,
    )
    println(io, "  ⇒ C₄(F₁) ≇ C₄(F₁⁻¹+b) for all b follows from Theorem 6 (iff) and the")
    println(io, "    complete are_affine_equivalent decision; a direct code-equivalence")
    println(io, "    computation requires MAGMA / Leon's algorithm.")

    # Positive control for Theorem 6's forward direction: Dillon is AE to F₂,
    # so C₄(Dillon) ≅ C₄(F₂+b) for some b — their WEs must match for some b.
    D = dillon_apn_permutation()
    F2 = calderini_f2()
    w4D = code_weight_enumerator(c4_matrix(D))
    found = any(
        code_weight_enumerator(
            c4_matrix(SBox{6}([F2.lut[x + 1] ⊻ UInt8(b) for x = 0:63])),
        ) == w4D for b = 0:63
    )
    print_check(io, "∃b: WE(C₄(F₂+b)) == WE(C₄(Dillon))  [D AE F₂, forward direction]", found)
    ok &= found
    return ok
end

"""
    section4_report(io)

Section 4: paper-exact code dimensions, Theorem 5 WE demos, Theorem 6 demo.
"""
function section4_report(io::IO = stdout)
    println(io, "# Calderini (2020) — Section 4: Equivalence relations and linear codes")
    println(io, "# Scope: C₁..C₄ dims (exact), Theorem 5/6 via weight enumerators +")
    println(io, "#        complete affine-equivalence decisions")

    print_section(io, "Code matrix dimensions for Gold x³ (n=5)")
    F5 = load_apn_function("n5_Gold_x3")
    d = verify_code_dimensions(F5)
    print_check(io, "C₁(F) = (2n+1)×2ⁿ = $(d.expected_C1)", d.ok1)
    print_check(io, "C₂(F) = (2n+1)×(2^{n+1}-1) = $(d.expected_C2)", d.ok2)
    print_check(io, "C₃(F) = (2n+1)×(2^{n+1}+2ⁿ-2) = $(d.expected_C3)", d.ok3)
    println(io, "  (C₄ needs a permutation; checked for F₁ below.)")

    print_section(io, "Theorem 5 — code equivalence ↔ function equivalence (WE level)")
    println(io, "  F CCZ~ G  ⟺  C₁(F) ≅ C₁(G)   [Browning-Dillon-McQuistan-Wolfe]")
    println(io, "  F EA~  G  ⟺  C₂(F) ≅ C₂(G)   [Edel-Pott Thm 10]")
    println(io, "  F AE~  G (non-perm, NL≠0) ⟺ C₃(F) ≅ C₃(G); for permutations C₃")
    println(io, "  detects AE to G or G⁻¹ only. Equal WE is necessary for code equiv;")
    println(io, "  unequal WE proves inequivalence.")
    theorem5_demo(io)

    print_section(io, "Theorem 6 — C₄ separates F₁ from F₁⁻¹ where C₃ cannot")
    theorem6_demo(io)
end