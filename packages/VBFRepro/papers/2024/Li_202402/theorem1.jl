# Implements Section 3: An Infinite Family of APN Functions over F_{2^{3m}}
# Paper: Li, Kaleyski (2024), "Two New Infinite Families of APN Functions in Trivariate Form"
# Section: 3 — Theorem 1 (APN, diff. unif. = 2^k) and Theorem 3 (permutation, m/k odd)
#
# Pseudocode:
#   1. q = 2^i, k = gcd(i,m), work in GF(2^m)
#   2. F(x,y,z) = (x^{q+1}+x^q·z+y·z^q,  x^q·z+y^{q+1},  x·y^q+y^q·z+z^{q+1})
#   3. Build LUT, verify differential_uniformity = 2^k  (Theorem 1)
#   4. Verify is_permutation when m/k is odd             (Theorem 3)
#   5. Check three univariate root conditions:
#        X^{q²+q+1}+X+1,  X^{q²+q+1}+X^{q²}+1,  X^{q²+q+1}+X^{q²+1}+X^{q+1}+X+1
#   6. Check bivariate condition (Theorem 1):
#        X^{q²+q+1}+XY^{q²+q}+XY^q+X^{q²+q}+X^qY^{q²}+X^{q²}Y
#        +Y^{q²+q+1}+Y^{q²+q}+Y^{q²}+Y^q+1  has no roots in GF(2^m)^2
# VBF API used: gf_mul, gf_pow, primitive_polynomial,
#               differential_uniformity, is_permutation, SBox, print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

"""
    family1_lut(m, i) -> Vector{Int}

LUT for Theorem 1 Family 1: F(x,y,z) = (x^{q+1}+x^q·z+y·z^q, x^q·z+y^{q+1}, x·y^q+y^q·z+z^{q+1})
over GF(2^m)^3, where q = 2^i and k = gcd(i,m).
Encoding: idx = x·2^{2m} + y·2^m + z.
"""
function family1_lut(m::Int, i::Int)::Vector{Int}
    q  = 1 << i
    pp = primitive_polynomial(m)
    pow(x, e) = gf_pow(x, e, m; modulus = pp)
    mul(a, b) = gf_mul(a, b, m; modulus = pp)

    trivariate_lut(m, function (x, y, z)
        xq = pow(x, q);  yq = pow(y, q);  zq = pow(z, q)
        f1 = mul(xq, x) ⊻ mul(xq, z) ⊻ mul(y,  zq)   # x^{q+1} + x^q·z + y·z^q
        f2 = mul(xq, z) ⊻ mul(yq, y)                   # x^q·z + y^{q+1}
        f3 = mul(x, yq) ⊻ mul(yq, z) ⊻ mul(zq, z)     # x·y^q + y^q·z + z^{q+1}
        return f1, f2, f3
    end)
end

"""
    theorem1_root_conditions(m, i) -> (c1, c2, c3)

Verify Theorem 1's three univariate sufficient conditions for APN-ness:
- c1: X^{q²+q+1}+X+1        has no roots in GF(2^m)
- c2: X^{q²+q+1}+X^{q²}+1  has no roots in GF(2^m)
- c3: X^{q²+q+1}+X^{q²+1}+X^{q+1}+X+1 has no roots in GF(2^m)

For i=1 (q=2): c1=X^7+X+1, c2=X^7+X^4+1, c3=X^7+X^5+X^3+X+1 — all irreducible over F_2
with roots in GF(2^7), so root-free in GF(2^m) whenever gcd(m,7)=1 (Proposition 4 proof, p.17).

The fourth condition (bivariate poly, Theorem 1) factors over GF(2^7) for q=2;
the sufficient hypothesis is checked directly by theorem1_bivariate_condition.
"""
function theorem1_root_conditions(m::Int, i::Int)
    q    = 1 << i
    pp   = primitive_polynomial(m)
    pow(x, e) = gf_pow(x, e, m; modulus = pp)
    q2q1 = q * q + q + 1
    q2q  = q * q + q
    q2   = q * q

    c1 = poly_no_roots_f2m(m) do x
        pow(x, q2q1) ⊻ x ⊻ 1
    end
    c2 = poly_no_roots_f2m(m) do x
        pow(x, q2q1) ⊻ pow(x, q2) ⊻ 1
    end
    c3 = poly_no_roots_f2m(m) do x
        pow(x, q2q1) ⊻ pow(x, q2+1) ⊻ pow(x, q+1) ⊻ x ⊻ 1
    end
    return c1, c2, c3
end

"""Check the complete bivariate no-root hypothesis in Theorem 1 over GF(2^m)^2."""
function theorem1_bivariate_condition(m::Int, i::Int)
    q = 1 << i; q2 = q*q; pp = primitive_polynomial(m)
    pow(x,e) = gf_pow(x,e,m;modulus=pp)
    mul(x,y) = gf_mul(x,y,m;modulus=pp)
    return bipoly_no_roots_f2m(m) do x,y
        pow(x,q2+q+1) ⊻ mul(x,pow(y,q2+q)) ⊻ mul(x,pow(y,q)) ⊻
        pow(x,q2+q) ⊻ mul(pow(x,q),pow(y,q2)) ⊻ mul(pow(x,q2),y) ⊻
        pow(y,q2+q+1) ⊻ pow(y,q2+q) ⊻ pow(y,q2) ⊻ pow(y,q) ⊻ 1
    end
end

"""
    theorem1_report(; m, i, io) -> NamedTuple

Theorem 1 & 3 report for Family 1 with parameters m and i.
Checks root conditions, APN property, and permutation (when m/k odd).
"""
function theorem1_report(; m::Int = 3, i::Int = 1, io::IO = stdout)
    k = gcd(i, m)
    q = 1 << i
    n = 3m

    print_section("Theorem 1/3 — Family 1  [m=$m, i=$i, q=$q, k=$k, n=$n]", io)

    c1, c2, c3 = theorem1_root_conditions(m, i)
    print_check("X^{q²+q+1}+X+1  no roots in GF(2^$m)", c1, io)
    print_check("X^{q²+q+1}+X^{q²}+1  no roots in GF(2^$m)", c2, io)
    print_check("X^{q²+q+1}+X^{q²+1}+X^{q+1}+X+1  no roots in GF(2^$m)", c3, io)
    c4 = theorem1_bivariate_condition(m, i)
    print_check("bivariate polynomial has no roots in GF(2^m)^2", c4, io)

    lut = family1_lut(m, i)
    du  = differential_uniformity(SBox(lut))
    exp_du = 1 << k
    print_check("differential_uniformity(F₁) = 2^k = $exp_du  [got $du]  (Theorem 1)", du == exp_du, io)

    mk = m ÷ k
    perm_ok = nothing
    if mk % 2 == 1
        perm_ok = is_permutation(SBox(lut))
        print_check("F₁ is permutation over GF(2^$n)  [m/k=$mk odd]  (Theorem 3)", perm_ok, io)
    else
        print_kv("permutation check (Theorem 3)", "skipped — m/k=$mk even", io)
    end

    return (; conditions = (c1, c2, c3), bivariate_condition=c4, hypotheses_hold=c1 && c2 && c3 && c4, du, perm_ok, lut)
end

if abspath(PROGRAM_FILE) == @__FILE__
    include(joinpath(@__DIR__, "helpers.jl"))
    print_header()
    theorem1_report(m = 3, i = 1)
    theorem1_report(m = 3, i = 2)
    theorem1_report(m = 4, i = 1)
end
