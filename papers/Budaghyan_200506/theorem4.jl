# Implements Section 5, Theorem 4 — AB polynomials for m odd, n | m.
# Paper: Budaghyan, Carlet, Pott (2006), "New Classes of Almost Bent and Almost
#        Perfect Nonlinear Polynomials", IEEE Trans. IT 52(3), pp. 762–777.
# Section: 5 — New cases of AB and APN functions
#
# Pseudocode:
#   F1(x) = x + trm/n(x) + trm/n(x^{2^i+1})
#   F2(x) = x^{2^i+1} + trm/n(x)
#   F'    = F2 ∘ F1^{-1}                  (Theorem 4 construction)
#
#   NOTE: The explicit formula for F' in the theorem statement (via F1^{-1}) is
#   incorrect for some (m, n, i) combinations — verified numerically for i=2 on
#   GF(2^9). The underlying construction F' = F2 ∘ F1^{-1} is always correct;
#   we implement it by permutation inversion, as done for Theorem 3.
#
#   AB ↔ linearity = 2^{(m+1)/2};  degree = n+2
# VBF API used: gf_mul, gf_pow, primitive_polynomial, SBox, linearity,
#               algebraic_degree

include(joinpath(@__DIR__, "helpers.jl"))

"""
    theorem4_lut(m, n, i; modulus) -> Vector{Int}

LUT of the Theorem 4 AB function F' = F₂ ∘ F₁⁻¹ over GF(2^m), where
  F₁(x) = x + trm/n(x) + trm/n(x^{2^i+1})
  F₂(x) = x^{2^i+1} + trm/n(x)
and F₁⁻¹ is obtained by permutation inversion.

Requires m > 3 odd, n | m, m ≠ n, gcd(i, m) = 1.
"""
function theorem4_lut(
    m::Int,
    n::Int,
    i::Int;
    modulus::Int = primitive_polynomial(m),
)
    m > 3 || throw(ArgumentError("theorem4_lut: need m > 3, got m=$m"))
    m % 2 == 1 || throw(ArgumentError("theorem4_lut: m must be odd, got m=$m"))
    (m % n == 0 && m != n) || throw(ArgumentError("theorem4_lut: need n|m and m≠n, got m=$m, n=$n"))
    gcd(i, m) == 1 || throw(ArgumentError("theorem4_lut: need gcd(i,m)=1, got i=$i, m=$m"))

    gold_exp = (1 << i) + 1
    N = 1 << m

    F1(x) = begin
        xg = gf_pow(x, gold_exp, m; modulus = modulus)
        x ⊻ gf_relative_trace(x, m, n; modulus = modulus) ⊻
        gf_relative_trace(xg, m, n; modulus = modulus)
    end
    F2(x) = gf_pow(x, gold_exp, m; modulus = modulus) ⊻
            gf_relative_trace(x, m, n; modulus = modulus)

    lut_F1 = [F1(x) for x in 0:N-1]
    lut_F1inv = Vector{Int}(undef, N)
    for x in 0:N-1
        lut_F1inv[lut_F1[x+1]+1] = x
    end

    [F2(lut_F1inv[x+1]) for x in 0:N-1]
end

"""
    theorem4_check(; m, n, i, io) -> NamedTuple

Verify Theorem 4 claims for one (m, n, i) triple:
- F' is AB (linearity = 2^{(m+1)/2}, implying APN)
- algebraic degree = n+2
"""
function theorem4_check(; m::Int, n::Int, i::Int, io::IO = devnull)
    modulus = primitive_polynomial(m)
    lut = theorem4_lut(m, n, i; modulus = modulus)
    s = SBox{m}(lut)

    ab_target = 1 << ((m + 1) ÷ 2)
    is_ab = linearity(s) == ab_target
    deg = algebraic_degree(s)
    expected_deg = n + 2

    print_section("Theorem 4 — GF(2^$m), n=$n, i=$i", io)
    print_check("AB (linearity = $ab_target)", is_ab, io)
    print_check("algebraic degree = $expected_deg", deg == expected_deg, io)
    print_kv("actual degree", deg, io)

    (; is_ab, deg, expected_deg)
end

function theorem4_report(io::IO = stdout)
    print_section("Section 5 — Theorem 4: AB polynomials (m odd, n|m)", io)
    theorem4_check(; m = 9, n = 3, i = 1, io = io)
    theorem4_check(; m = 9, n = 3, i = 2, io = io)
    print_kv("note", "m=15 omitted (APN check O(4^15) ~ 10^9 ops)", io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    theorem4_report()
end
