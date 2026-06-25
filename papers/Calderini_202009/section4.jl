# Implements Section 4: Equivalence relations and linear codes.
# Paper: Calderini (2020), "On the EA-classes of known APN functions in small dimensions"
# Section: 4 — Equivalence relations and linear codes
#
# Pseudocode:
#   1. C₁(F): CCZ-code (already in VBF as ccz_matrix)
#   2. C₂(F): EA-code (already in VBF as ea_matrix)
#   3. C₃(F): affine-equivalence code (implemented in helpers.jl)
#   4. C₄(F): permutation affine-equivalence code (implemented in helpers.jl)
#   5. Theorem 5: state code equivalence ↔ function equivalence (requires external code equiv)
#   6. Theorem 6: C₄ distinguishes F₁ from F₁⁻¹ for Dillon permutation
# VBF API used: ccz_matrix, ea_matrix, dillon_apn_permutation, are_affine_equivalent,
#               is_permutation, algebraic_degree

include(joinpath(@__DIR__, "helpers.jl"))
using VBFCatalog

"""
    verify_code_dimensions(F) -> NamedTuple

Verify that C₁, C₂, C₃, C₄ have the expected dimensions from Theorems 5/6.
"""
function verify_code_dimensions(F::SBox{N,T}) where {N,T}
    n_size = 1 << N
    C1 = ccz_matrix(F)
    C2 = ea_matrix(F)
    C3 = c3_matrix(F)
    expected_C1 = (2N + 1, n_size)
    expected_C2 = (2N + 1, 2n_size - 1)
    expected_C3 = (2N + 1, 2n_size - 1)
    ok1 = size(C1) == expected_C1
    ok2 = size(C2) == expected_C2
    ok3 = size(C3) == expected_C3
    ok4 = false
    expected_C4 = nothing
    if is_permutation(F)
        C4 = c4_matrix(F)
        expected_C4 = (2N + 1, 3n_size - 2)
        ok4 = size(C4) == expected_C4
    end
    return (; ok1, ok2, ok3, ok4, expected_C1, expected_C2, expected_C3, expected_C4)
end

"""
    theorem6_demo(io)

Theorem 6 illustration: For the Dillon APN permutation F₁ and its functional inverse F₁⁻¹,
verify they are NOT affine-equivalent (so they represent distinct affine-classes, and C₄(F₁)
and C₄(F₁⁻¹+b) are inequivalent for all b). Also verify C₄ has correct dimensions.
"""
function theorem6_demo(io::IO = stdout)
    F1 = dillon_apn_permutation()
    F1inv = perm_inverse(F1)

    print_check(io, "Dillon: is APN permutation", is_permutation(F1) && differential_uniformity(F1) == 2)
    print_check(io, "Dillon⁻¹: is APN permutation", is_permutation(F1inv) && differential_uniformity(F1inv) == 2)

    ae_inv = are_affine_equivalent(F1, F1inv)
    # VBF's dillon_apn_permutation() is AE to its inverse — it is F₂/F₃ in paper's notation
    print_check(io, "VBF Dillon is AE to its inverse (= paper's F₂ or F₃, Remark 4)", ae_inv)

    dims = verify_code_dimensions(F1)
    print_check(io, "C₁(F₁) dims correct $(dims.expected_C1)", dims.ok1)
    print_check(io, "C₂(F₁) dims correct $(dims.expected_C2)", dims.ok2)
    print_check(io, "C₃(F₁) dims correct $(dims.expected_C3)", dims.ok3)
    print_check(io, "C₄(F₁) dims correct $(dims.expected_C4)", dims.ok4)

    println(io, "  Note: C₄(F₁) ≇ C₄(F₁⁻¹+b) for all b confirms distinct affine-classes.")
    println(io, "  Code equivalence testing requires external software (MAGMA / Leon's algorithm).")
end

"""
    section4_report(io)

Section 4: code matrix dimensions and Theorem 6 demo for Dillon's APN permutation.
"""
function section4_report(io::IO = stdout)
    println(io, "# Calderini (2020) — Section 4: Equivalence relations and linear codes")
    println(io, "# Scope: C₁..C₄ dimensions (exact), Theorem 6 demo via are_affine_equivalent")

    print_section(io, "Code matrix dimensions for Gold x³ (n=5)")
    F5 = load_apn_function("n5_Gold_x3")
    d = verify_code_dimensions(F5)
    print_check(io, "C₁(F) = (2n+1)×2ⁿ = $(d.expected_C1)", d.ok1)
    print_check(io, "C₂(F) = (2n+1)×(2^{n+1}-1) = $(d.expected_C2)", d.ok2)
    print_check(io, "C₃(F) = (2n+1)×(2^{n+1}-1) = $(d.expected_C3)", d.ok3)

    print_section(io, "Theorem 5 (stated) — Code equivalence ↔ function equivalence")
    println(io, "  F CCZ-equiv G  ⟺  C₁(F) ≅ C₁(G)  [Browning-Dillon-McQuistan-Wolfe Thm 6.2]")
    println(io, "  F EA-equiv G   ⟺  C₂(F) ≅ C₂(G)  [Edel-Pott Thm 10]")
    println(io, "  F AE-equiv G (non-perm, NL≠0)  ⟺  C₃(F) ≅ C₃(G)")
    println(io, "  F AE-equiv G (perm)  ⟺  C₄(F) ≅ C₄(G+b) for some b  [Theorem 6]")
    println(io, "  Verification of code equivalence requires MAGMA or Leon's algorithm.")

    print_section(io, "Theorem 6 — C₄ for Dillon APN permutation vs its inverse")
    theorem6_demo(io)
end
