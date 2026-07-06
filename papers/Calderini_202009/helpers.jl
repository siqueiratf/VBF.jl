# Implements shared helpers for Calderini (2020) paper reproduction.
# Paper: Calderini (2020), "On the EA-classes of known APN functions in small dimensions"
# Cryptography and Communications 12:821-840
#
# Field convention: the paper computes in MAGMA, whose default GF(2⁶) generator
# is the Conway-polynomial root (x⁶+x⁴+x³+x+1). All ζ-power coefficients from
# the paper are therefore interpreted with `conway_polynomial(n)` as modulus and
# ζ = 0b10. Empirical confirmation: the Section 5.1 polynomials F₁, F₂, F₃ are
# APN permutations under the Conway modulus, and are NOT APN under
# `primitive_polynomial(6)` = x⁶+x+1; likewise VBF's `kim_apn()` (Conway) matches
# the paper's Kim function x³ + ζx²⁴ + x¹⁰ exactly.
#
# Pseudocode:
#   1. Section 4 code matrices: the paper's C₂/C₃/C₄ are the VBF core exports
#      `ea_matrix` / `ae_matrix` / `ae_perm_matrix` (promoted into core from
#      this reproduction, together with `code_weight_enumerator`).
#   2. ZW(λ), S_F: Procedure 2 sets (Section 3, eq. 4).
#   3. sbox_from_zeta_terms: build an SBox from paper (ζ-power, exponent) terms
#      + the explicit Section 5.1 representatives F₁, F₂, F₃.
#   4. Utilities: power_sbox (via gf_monomial_lut), component_walsh_spectra,
#      cyclotomic_coset. EA-class censuses use the core `ea_class_orbits`
#      (also promoted from this reproduction).
# VBF API used: lat, conway_polynomial, gf_pow, gf_monomial_lut, terms_to_lut,
#               algebraic_degree, is_permutation, ea_matrix, ae_matrix,
#               ae_perm_matrix, code_weight_enumerator, ea_class_orbits,
#               component_degree_spectrum

using VBF

"""
    zw_set(F, λ) -> Vector{Int}

ZW(λ) = {a ∈ F₂ⁿ : W_{F_λ}(a) = 0} — zero-Walsh set for the λ-component of F.
Used in Procedure 2 to find admissible linear maps (Section 3).
"""
function zw_set(F::SBox{N,T}, λ::Integer) where {N,T}
    n_size = 1 << N
    L = lat(F)
    return Int[a for a = 0:(n_size - 1) if L[a + 1, Int(λ) + 1] == 0]
end

"""
    sf_set(F) -> Vector{Int}

S_F = {λ ∈ F₂ⁿ : ZW(λ) ≠ ∅} ∪ {0} — support set for Procedure 2 (Section 3, eq. 4).
"""
function sf_set(F::SBox{N,T}) where {N,T}
    n_size = 1 << N
    L = lat(F)
    S = Int[0]
    for λ = 1:(n_size - 1)
        if any(L[a + 1, λ + 1] == 0 for a = 1:(n_size - 1))
            push!(S, λ)
        end
    end
    return S
end

"""
    sbox_from_zeta_terms(n, terms) -> SBox

Build `Σ ζ^c · x^e` over GF(2ⁿ) from `(c, e)` pairs, with ζ the Conway
generator (paper/MAGMA convention; see the field-convention note above).
"""
function sbox_from_zeta_terms(n::Int, terms::Vector{Tuple{Int,Int}})
    mod = conway_polynomial(n)
    ts = Tuple{Int,Int}[(gf_pow(2, c, n; modulus = mod), e) for (c, e) in terms]
    SBox{n}(terms_to_lut(ts, n, mod))
end

"""
    power_sbox(n, d) -> SBox

x ↦ xᵈ over GF(2ⁿ) with Conway polynomial modulus (paper/MAGMA convention).
Thin wrapper over the VBF core export `gf_monomial_lut`.
"""
power_sbox(n::Int, d::Int) =
    SBox{n}(gf_monomial_lut(n, d; modulus = conway_polynomial(n)))

"""
    component_walsh_spectra(F) -> Vector{Pair{Vector{Pair{Int,Int}},Int}}

Multiset of per-component Walsh spectra: for each non-zero component λ the
sorted `value => multiplicity` spectrum of W_{F_λ}, collected as
`spectrum => #components` pairs sorted by count. This is the paper's
Section 5.1 per-component multi-set; compare multisets via `Dict(...)`
(the sorted order of equal counts is not canonical).
"""
function component_walsh_spectra(F::SBox{N,T}) where {N,T}
    n_size = 1 << N
    L = lat(F)
    seen = Dict{Vector{Pair{Int,Int}},Int}()
    for λ = 1:(n_size - 1)
        spec = Dict{Int,Int}()
        for a = 0:(n_size - 1)
            w = L[a + 1, λ + 1]
            spec[w] = get(spec, w, 0) + 1
        end
        key = sort!(collect(spec); by = first)
        seen[key] = get(seen, key, 0) + 1
    end
    return sort!(collect(seen); by = last)
end

"""
    cyclotomic_coset(d, m) -> Vector{Int}

Cyclotomic coset of `d` modulo `m` (orbit of d under multiplication by 2).
`x^d` and `x^e` over GF(2ⁿ) (m = 2ⁿ-1) are linearly equivalent when `e` lies
in the coset of `d`.
"""
function cyclotomic_coset(d::Int, m::Int)
    c = Int[]
    x = mod(d, m)
    while true
        push!(c, x)
        x = mod(2x, m)
        x == c[1] && break
    end
    return c
end

# ---------------------------------------------------------------------------
# Section 5.1 explicit representatives (paper eq. after line "Let", Section 5.1)
# (ζ-power, exponent) pairs transcribed from the published polynomials.
# F₁: not affine-equivalent to its inverse; F₂, F₃: AE to their inverses
# (Remark 4). VBF's `dillon_apn_permutation()` is affine-equivalent to F₂.
# ---------------------------------------------------------------------------

const CALDERINI_F1_TERMS = Tuple{Int,Int}[
    (57, 60), (56, 58), (43, 57), (31, 56), (29, 53), (27, 52), (28, 51),
    (35, 50), (54, 49), (51, 48), (1, 46), (54, 44), (50, 43), (50, 42),
    (32, 41), (49, 40), (36, 39), (14, 38), (16, 37), (15, 35), (43, 34),
    (23, 33), (7, 32), (7, 30), (57, 29), (11, 26), (49, 25), (36, 24),
    (42, 23), (40, 22), (34, 21), (9, 20), (28, 19), (4, 18), (50, 17),
    (58, 16), (1, 15), (48, 14), (33, 13), (31, 12), (43, 11), (14, 10),
    (5, 9), (45, 8), (60, 7), (31, 6), (42, 5), (10, 4), (10, 3), (48, 1),
]
const CALDERINI_F2_TERMS = Tuple{Int,Int}[
    (3, 60), (33, 58), (18, 57), (8, 56), (38, 53), (28, 52), (5, 51),
    (37, 50), (9, 49), (45, 48), (10, 46), (54, 44), (25, 43), (50, 42),
    (55, 41), (30, 40), (45, 39), (41, 38), (14, 37), (49, 36), (31, 35),
    (0, 34), (46, 33), (20, 32), (47, 30), (32, 29), (57, 28), (47, 26),
    (44, 25), (17, 24), (19, 23), (61, 22), (31, 21), (31, 20), (48, 19),
    (58, 18), (21, 17), (0, 16), (39, 15), (44, 14), (35, 13), (21, 12),
    (15, 11), (54, 10), (62, 9), (42, 8), (62, 7), (14, 6), (3, 5),
    (29, 4), (34, 3), (5, 2), (46, 1),
]
const CALDERINI_F3_TERMS = Tuple{Int,Int}[
    (61, 60), (60, 58), (49, 57), (24, 56), (21, 54), (16, 53), (36, 52),
    (35, 51), (17, 50), (28, 49), (14, 48), (62, 46), (9, 45), (21, 44),
    (29, 43), (22, 42), (35, 41), (41, 40), (51, 39), (46, 38), (37, 37),
    (7, 36), (32, 35), (45, 34), (16, 33), (55, 32), (11, 30), (8, 29),
    (29, 28), (6, 27), (58, 26), (28, 24), (15, 23), (44, 22), (35, 21),
    (32, 20), (53, 19), (42, 18), (50, 17), (0, 16), (12, 15), (27, 14),
    (30, 13), (7, 12), (52, 11), (43, 10), (7, 9), (17, 8), (5, 7),
    (17, 6), (43, 5), (13, 4), (57, 3), (35, 2), (49, 1),
]

"Section 5.1 representative F₁ (not AE to its inverse)."
calderini_f1() = sbox_from_zeta_terms(6, CALDERINI_F1_TERMS)
"Section 5.1 representative F₂ (AE to its inverse, Remark 4)."
calderini_f2() = sbox_from_zeta_terms(6, CALDERINI_F2_TERMS)
"Section 5.1 representative F₃ (AE to its inverse, Remark 4)."
calderini_f3() = sbox_from_zeta_terms(6, CALDERINI_F3_TERMS)
