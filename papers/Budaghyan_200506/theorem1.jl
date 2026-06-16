# Implements Section 5, Theorem 1 — AB polynomials for m > 3 odd.
# Paper: Budaghyan, Carlet, Pott (2006), "New Classes of Almost Bent and Almost
#        Perfect Nonlinear Polynomials", IEEE Trans. IT 52(3), pp. 762–777.
# Section: 5 — New cases of AB and APN functions
#
# Pseudocode:
#   F'(x) = x^{2^i+1} + (x^{2^i} + x) · tr(x^{2^i+1} + x)
#   1. Gold: xgold = x^{2^i+1};  Frobenius: xi = x^{2^i}
#   2. tr_val = tr(xgold ⊕ x) ∈ {0,1}
#   3. F'(x) = xgold ⊕ (tr_val == 1 ? (xi ⊕ x) : 0)
#   4. AB ↔ linearity = 2^{(m+1)/2};  APN ↔ diff_unif = 2
#   5. Prop 4: deg(tr(F')) = 2 ∉ {0,1,3=deg(F')}
# VBF API used: gf_pow, primitive_polynomial, SBox, differential_uniformity, linearity,
#               algebraic_degree

include(joinpath(@__DIR__, "helpers.jl"))

"""
    theorem1_lut(m, i; modulus) -> Vector{Int}

LUT of F'(x) = x^{2^i+1} + (x^{2^i} + x)·tr(x^{2^i+1} + x) over GF(2^m).
Requires m > 3 odd and gcd(i, m) = 1.
"""
function theorem1_lut(m::Int, i::Int; modulus::Int = primitive_polynomial(m))
    m > 3 || throw(ArgumentError("theorem1_lut: need m > 3, got m=$m"))
    m % 2 == 1 || throw(ArgumentError("theorem1_lut: m must be odd, got m=$m"))
    gcd(i, m) == 1 || throw(ArgumentError("theorem1_lut: need gcd(i,m)=1, got i=$i, m=$m"))
    gold_exp = (1 << i) + 1
    frob_exp = 1 << i
    N = 1 << m
    out = Vector{Int}(undef, N)
    for x in 0:N-1
        xgold = gf_pow(x, gold_exp, m; modulus = modulus)
        xi = gf_pow(x, frob_exp, m; modulus = modulus)
        tr_val = gf_trace(xgold ⊻ x, m; modulus = modulus)
        out[x+1] = xgold ⊻ (tr_val == 1 ? (xi ⊻ x) : 0)
    end
    out
end

"""
    theorem1_check(; m, i, io) -> NamedTuple

Verify Theorem 1 claims:
- F' is APN and AB
- algebraic degree = 3
- Prop 4: deg(tr(F')) = 2 ∉ {0, 1, 3}
"""
function theorem1_check(; m::Int, i::Int, io::IO = devnull)
    modulus = primitive_polynomial(m)
    lut = theorem1_lut(m, i; modulus = modulus)
    s = SBox{m}(lut)

    is_apn = differential_uniformity(s) == 2
    ab_target = 1 << ((m + 1) ÷ 2)
    is_ab = linearity(s) == ab_target
    deg = algebraic_degree(s)
    tt = trace_component_tt(lut, m; modulus = modulus)
    deg_tr = boolean_alg_degree(tt)
    prop4_ok = deg_tr ∉ (0, 1, deg)

    print_section("Theorem 1 — GF(2^$m), i=$i", io)
    print_check("APN (differential uniformity = 2)", is_apn, io)
    print_check("AB  (linearity = $ab_target)", is_ab, io)
    print_check("algebraic degree = 3", deg == 3, io)
    print_check("Prop 4: deg(tr(F')) = $deg_tr ∉ {0,1,$deg}", prop4_ok, io)

    (; is_apn, is_ab, deg, deg_tr, prop4_ok)
end

function theorem1_report(io::IO = stdout)
    print_section("Section 5 — Theorem 1: AB polynomials (m > 3 odd)", io)
    for (m, i) in [(5, 1), (5, 2), (7, 1), (7, 2), (7, 3)]
        theorem1_check(; m = m, i = i, io = io)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    theorem1_report()
end
