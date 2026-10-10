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
#   8. ea_verdict(F, G)      — sound EA decision: EA oracle, then CCZ separation
# VBF API used: gf_mul, gf_pow, gf_monomial_lut, primitive_polynomial, SBox,
#               gold_apn, welch_apn, kasami_apn, inverse_apn,
#               differential_uniformity, algebraic_degree, is_permutation,
#               are_ea_equivalent, are_ccz_equivalent, are_affine_equivalent

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

The five APN power-function permutations for n=5, in the order of the paper's
Table 1 `Aff.` column: x³, x⁵, x⁷, x¹¹, x¹⁵. They represent the 5
affine-equivalence classes of APN permutations (Table 1, Theorem 3).

Family attribution — the paper lists only the exponent, and x¹⁵ is **not**
Kasami (an earlier version of this file said so):

  * x³  = `gold_apn(5, 1)`, exponent 2¹+1.
  * x⁵  = `gold_apn(5, 2)`, exponent 2²+1.
  * x⁷  = `welch_apn(5)`,   exponent 2ᵗ+3 with t = 2.
  * x¹¹ is the **Kasami** class: the Kasami exponent 2^{2k}−2^k+1 at k = 2 is
    13, and 11 lies in its cyclotomic coset {11,13,21,22,26}, so x¹¹ is linearly
    equivalent to `kasami_apn(5, 2)` = x¹³ (Frobenius).
  * x¹⁵ is the **Inverse** class (`2^{2t}−1` with t = 2): its coset
    {15,23,27,29,30} contains the inverse exponent 2⁵−2 = 30 (`inverse_apn(5)`)
    and the Dobbertin exponent 29 (`dobbertin_apn(5)`). Γ-rank separates it
    (496) from the Kasami class x¹¹ (330), so this is not a naming nicety.

`theorem3_n5_report` proves the two coset claims with `are_affine_equivalent`.
"""
function n5_power_sboxes()
    mod = primitive_polynomial(5)
    [
        gold_apn(5, 1; modulus = mod),   # x³
        gold_apn(5, 2; modulus = mod),   # x⁵
        welch_apn(5; modulus = mod),     # x⁷
        power_sbox(5, 11; modulus = mod),  # Kasami coset — see docstring
        power_sbox(5, 15; modulus = mod),  # Inverse coset — see docstring
    ]
end

"""
    n5_power_labels() -> Vector{String}

Family labels matching `n5_power_sboxes()`.
"""
n5_power_labels() = [
    "x³ (Gold k=1)",
    "x⁵ (Gold k=2)",
    "x⁷ (Welch)",
    "x¹¹ (Kasami coset)",
    "x¹⁵ (Inverse coset)",
]

"""
    n5_all_seven() -> Vector{SBox{5}}

All seven n=5 EA-class representatives (Theorem 5):
5 power-function classes (x³,x⁵,x⁷,x¹¹,x¹⁵) + 2 non-power classes from formula (6).
"""
function n5_all_seven()
    mod = primitive_polynomial(5)
    nonpow = [formula6_n5(i; modulus = mod) for i in [1, 2]]
    vcat(n5_power_sboxes(), nonpow)
end

"""
    n5_ccz_reps() -> (reps::Vector{SBox{5}}, labels::Vector{String})

The three n=5 CCZ-class representatives of Theorem 6: x³, x⁵, x¹⁵.

They are pairwise CCZ-inequivalent by *sound* arguments only:
  * x³ vs x⁵ — both are quadratic APN, so `are_ccz_equivalent` reduces to the
    exact ortho-derivative EA test (CCZ = EA on quadratic APN, Yoshiara 2012).
  * x¹⁵ vs the other two — the Γ-rank is a CCZ-invariant and separates
    x¹⁵ (496) from x³ and x⁵ (330). No search, no cap.
"""
function n5_ccz_reps()
    p = n5_power_sboxes()
    ([p[1], p[2], p[5]], ["x³", "x⁵", "x¹⁵"])
end

"""
    n5_ccz_class(F) -> Union{Int,Nothing}

Index into `n5_ccz_reps()` of the CCZ class of `F`, or `nothing` if no rep gave a
**positive** witness.

Only positive outcomes of `are_ccz_equivalent` are used, and a positive is always
backed by a witness (an EA-certificate against a class representative), so the
assignment never rests on a capped search. Γ-rank — a CCZ-invariant — pre-filters
the candidates, which also makes x¹⁵'s class assignment witness-free.
"""
function n5_ccz_class(F::SBox{5})
    reps, _ = n5_ccz_reps()
    g = gamma_rank(F)
    for (i, R) in enumerate(reps)
        gamma_rank(R) == g || continue          # CCZ-invariant pre-filter
        F.lut == R.lut && return i              # identity witness
        are_ccz_equivalent(F, R; on_inconclusive = :missing) === true && return i
    end
    nothing
end

"""
    ea_verdict(F, G; class_F = nothing, class_G = nothing)
        -> (equivalent::Union{Bool,Missing}, why::String)

Sound EA-equivalence verdict.

`are_ea_equivalent` defaults to `on_inconclusive = :best_effort`, which warns and
returns `false` when its bounded search is capped; reading that `false` as
"EA-inequivalent" turns an undecided pair into a claimed EA-class (the core
docstring calls this out as how a novelty check manufactures a discovery). So we
ask for `:missing` and, when the EA oracle is undecided, fall back to the
**CCZ separation argument**: EA-equivalence implies CCZ-equivalence, so functions
in distinct CCZ classes are EA-inequivalent.

`class_F` / `class_G` are `n5_ccz_class` indices. They are passed in rather than
recomputed because a *direct* `are_ccz_equivalent(F, G)` between two
non-quadratic permutations runs the Canteaut–Perrin enumeration on a Heggebakk
backend and can return an unsound `false`; the class indices instead come from
positive witnesses plus the Γ-rank invariant.

Returns `missing` when neither route decides.
"""
function ea_verdict(F::SBox, G::SBox; class_F = nothing, class_G = nothing)
    ea = are_ea_equivalent(F, G; on_inconclusive = :missing)
    ea === true && return (true, "EA oracle (witness)")
    ea === false && return (false, "EA oracle (exhaustive / invariant)")
    if class_F !== nothing && class_G !== nothing && class_F != class_G
        return (false, "CCZ separation — distinct CCZ classes ⇒ EA-inequivalent")
    end
    (missing, "UNDECIDED (EA search capped; CCZ classes agree or unknown)")
end

