# Implements shared helpers for Brinkmann & Leander (2008) paper reproduction.
# Paper: Brinkmann, Leander (2008), "On the Classification of APN Functions up to
#        Dimension Five", Designs, Codes and Cryptography 49(1-3):273-288.
#        DOI: 10.1007/s10623-008-9194-6
#
# Pseudocode:
#   1. gf_trace(x, n)        — absolute trace Tr_{GF(2^n)/GF(2)}(x) ∈ {0,1}
#   2. power_sbox(n, d)      — x↦xᵈ over GF(2ⁿ)
#   3. formula5_n4(i)        — non-power APN for n=4 (Budaghyan et al. [5], eq. 5)
#   4. formula6_n5(i)        — non-power APN for n=5 (Budaghyan et al. [5], eq. 6)
#   5. table2_luts()         — EA-canonical n=4 APN representatives (Table 2)
#   6. n5_power_sboxes()     — five APN permutations for n=5 (Table 1 classes)
#   7. n5_all_seven()        — all seven n=5 EA-class representatives (Theorem 5)
# VBF API used: gf_mul, gf_pow, gf_monomial_lut, primitive_polynomial, SBox,
#               differential_uniformity, algebraic_degree, is_permutation,
#               are_ea_equivalent, are_ccz_equivalent

using VBF
using Dates

"""
    power_sbox(n, d; modulus) -> SBox{n}

x ↦ xᵈ over GF(2ⁿ) with the canonical primitive polynomial modulus.
"""
function power_sbox(n::Int, d::Int; modulus::Int = primitive_polynomial(n))
    SBox{n}(gf_monomial_lut(n, d; modulus = modulus))
end

"""
    formula5_n4(i; modulus) -> SBox{4}

Non-power APN family for n=4 from Budaghyan, Carlet, Pott (2006) [ref 5].
Eq. (5): s(x) = x^{2ⁱ+1} + (x^{2ⁱ} + x + 1)·tr(x^{2ⁱ+1}), for i=1.
"""
function formula5_n4(i::Int = 1; modulus::Int = primitive_polynomial(4))
    n = 4
    gold = (1 << i) + 1
    SBox{4}([begin
        xg = gf_pow(x, gold, n; modulus = modulus)
        xi = gf_pow(x, 1 << i, n; modulus = modulus)
        tr = gf_trace(xg, n; modulus = modulus)
        xg ⊻ (tr == 0 ? 0 : (xi ⊻ x ⊻ 1))
    end for x in 0:15])
end

"""
    formula6_n5(i; modulus) -> SBox{5}

Non-power APN family for n=5 from Budaghyan, Carlet, Pott (2006) [ref 5].
Eq. (6): s(x) = x^{2ⁱ+1} + (x^{2ⁱ} + x)·tr(x^{2ⁱ+1} + x), for i=1 or i=2.
"""
function formula6_n5(i::Int; modulus::Int = primitive_polynomial(5))
    n = 5
    gold = (1 << i) + 1
    SBox{5}([begin
        xg = gf_pow(x, gold, n; modulus = modulus)
        xi = gf_pow(x, 1 << i, n; modulus = modulus)
        tr = gf_trace(xg ⊻ x, n; modulus = modulus)
        xg ⊻ (tr == 0 ? 0 : (xi ⊻ x))
    end for x in 0:31])
end

"""
    table2_luts() -> Tuple{SBox{4}, SBox{4}}

EA-canonical APN functions for n=4 from Table 2 of the paper.
F1 is EA-equivalent to Gold x³; F2 is from the non-power family [5].
Both vanish on the affine standard basis {0,1,2,4,8}.
"""
function table2_luts()
    F1 = SBox{4}([0, 0, 0, 1, 0, 2, 4, 7, 0, 4,  6,  3,  8, 14, 10, 13])
    F2 = SBox{4}([0, 0, 0, 1, 0, 2, 4, 7, 0, 4,  6,  3,  8, 14, 11, 12])
    (F1, F2)
end

"""
    n5_power_sboxes() -> Vector{SBox{5}}

Five APN power-function permutations for n=5: x³, x⁵, x⁷ (Welch), x¹¹, x¹⁵ (Kasami).
These represent the 5 affine-equivalence classes of APN permutations (Table 1, Theorem 3).
"""
function n5_power_sboxes()
    mod = primitive_polynomial(5)
    [power_sbox(5, d; modulus = mod) for d in [3, 5, 7, 11, 15]]
end

"""
    n5_all_seven() -> Vector{SBox{5}}

All seven n=5 EA-class representatives (Theorem 5):
5 power-function classes (x³,x⁵,x⁷,x¹¹,x¹⁵) + 2 non-power classes from formula (6).
"""
function n5_all_seven()
    mod = primitive_polynomial(5)
    powers = [power_sbox(5, d; modulus = mod) for d in [3, 5, 7, 11, 15]]
    nonpow = [formula6_n5(i; modulus = mod) for i in [1, 2]]
    vcat(powers, nonpow)
end

