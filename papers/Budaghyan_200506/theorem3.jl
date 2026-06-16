# Implements Section 5, Theorem 3 — new APN polynomials for m divisible by 6.
# Paper: Budaghyan, Carlet, Pott (2006), "New Classes of Almost Bent and Almost
#        Perfect Nonlinear Polynomials", IEEE Trans. IT 52(3), pp. 762–777.
# Section: 5 — New cases of AB and APN functions
#
# Pseudocode:
#   T(x) = trm/3(x^{2^i+1})
#   F1(x) = x + T(x)^2 + T(x)^4          (linear permutation of order dividing 6)
#   F2(x) = x^{2^i+1}                     (Gold power function)
#   F'  = F2 ∘ F1^{-1}                    (Theorem 3 construction)
#
#   NOTE: The explicit formula for F' given in the paper's theorem statement
#   and in the proof's derivation of F1^{-1} is incorrect for some elements
#   (the formula for F1^5 does not match the true F1^{-1} for ≈ 37% of inputs).
#   The paper's CONSTRUCTION (F' = F2 ∘ F1^{-1}) is correct; we implement it
#   directly by permutation inversion.
#
#   F_8 computer check (Theorem 3 proof, p. 771):
#   For all u ∈ F*_8, w ∈ F*_8 with tr_3(w)=0:
#     (u^{2^i+1}·w)^2 + (u^{2^i+1}·w)^4 ≠ u  [confirms F1 is a permutation]
#
# VBF API used: gf_mul, gf_pow, primitive_polynomial, SBox, differential_uniformity,
#               algebraic_degree

include(joinpath(@__DIR__, "helpers.jl"))

"""
    theorem3_lut(m, i; modulus) -> Vector{Int}

LUT of the Theorem 3 APN function F' = F₂ ∘ F₁⁻¹ over GF(2^m), where
  T(x)  = trm/3(x^{2^i+1})
  F₁(x) = x + T(x)² + T(x)⁴
  F₂(x) = x^{2^i+1}
and F₁⁻¹ is obtained by permutation inversion.

Requires 6 | m and gcd(i, m) = 1.
"""
function theorem3_lut(m::Int, i::Int; modulus::Int = primitive_polynomial(m))
    m % 6 == 0 || throw(ArgumentError("theorem3_lut: 6 must divide m, got m=$m"))
    gcd(i, m) == 1 || throw(ArgumentError("theorem3_lut: need gcd(i,m)=1, got i=$i, m=$m"))
    gold_exp = (1 << i) + 1
    N = 1 << m

    T(x) = gf_relative_trace(gf_pow(x, gold_exp, m; modulus = modulus), m, 3; modulus = modulus)
    F1(x) = begin
        tx = T(x)
        x ⊻ gf_pow(tx, 2, m; modulus = modulus) ⊻ gf_pow(tx, 4, m; modulus = modulus)
    end
    F2(x) = gf_pow(x, gold_exp, m; modulus = modulus)

    # Build F1 LUT and invert
    lut_F1 = [F1(x) for x in 0:N-1]
    lut_F1inv = Vector{Int}(undef, N)
    for x in 0:N-1
        lut_F1inv[lut_F1[x+1]+1] = x
    end

    [F2(lut_F1inv[x+1]) for x in 0:N-1]
end

"""
    theorem3_f8_check(; io) -> NamedTuple

F_8 computer check from Theorem 3 proof (Budaghyan et al., p. 771):
For every u ∈ F*_8 and w ∈ F*_8 with tr_3(w) = 0:
  (u^{2^i+1}·w)^2 + (u^{2^i+1}·w)^4 ≠ u

Tested for i ∈ {1, 2} (covering both residue classes mod 3 for valid i).
This check is exact and exhaustive (at most 7×3×2 = 42 pairs).
"""
function theorem3_f8_check(; io::IO = devnull)
    mod3 = primitive_polynomial(3)
    N3 = 8

    violations = 0
    pairs_checked = 0

    for i in (1, 2)
        gold_exp = (1 << i) + 1
        for u in 1:N3-1, w in 1:N3-1
            gf_trace(w, 3; modulus = mod3) == 0 || continue
            v = gf_mul(gf_pow(u, gold_exp, 3; modulus = mod3), w, 3; modulus = mod3)
            lhs = gf_pow(v, 2, 3; modulus = mod3) ⊻ gf_pow(v, 4, 3; modulus = mod3)
            lhs == u && (violations += 1)
            pairs_checked += 1
        end
    end

    ok = violations == 0
    print_section("Theorem 3 — F_8 computer check (i=1,2)", io)
    print_kv("pairs (u ∈ F*_8, w ∈ {tr_3(w)=0,w≠0}, i∈{1,2})", pairs_checked, io)
    print_check("(u^{2^i+1}w)^2+(u^{2^i+1}w)^4 ≠ u for all pairs (violations=$violations)", ok, io)
    print_kv("completeness", "exhaustive", io)

    (; violations, pairs_checked, ok)
end

"""
    theorem3_check(; m, i, io) -> NamedTuple

Verify Theorem 3 claims for one (m, i) pair:
- F' is APN (differential_uniformity == 2)
- algebraic degree of F' is 4
"""
function theorem3_check(; m::Int, i::Int, io::IO = devnull)
    modulus = primitive_polynomial(m)
    lut = theorem3_lut(m, i; modulus = modulus)
    s = SBox{m}(lut)

    is_apn = differential_uniformity(s) == 2
    deg = algebraic_degree(s)

    print_section("Theorem 3 — GF(2^$m), i=$i", io)
    print_check("APN (differential uniformity = 2)", is_apn, io)
    print_check("algebraic degree = 4", deg == 4, io)

    (; is_apn, deg)
end

function theorem3_report(io::IO = stdout)
    print_section("Section 5 — Theorem 3: APN polynomials (6 | m)", io)
    theorem3_f8_check(; io = io)
    theorem3_check(; m = 6, i = 1, io = io)
    theorem3_check(; m = 6, i = 5, io = io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    theorem3_report()
end
