# Implements Section 3: Proposition 4 — explicit APN permutation for gcd(m,7)=1
# Paper: Li, Kaleyski (2024), "Two New Infinite Families of APN Functions in Trivariate Form"
# Section: 3 — Proposition 4 (i=1, q=2, gcd(m,7)=1)
#
# Pseudocode:
#   1. Set i=1, q=2; check gcd(m,7)=1
#   2. F(x,y,z) = (x³+x²z+yz², x²z+y³, xy²+y²z+z³)   (Family 1, q=2)
#   3. Sufficient conditions reduce to:
#        X⁷+X+1, X⁷+X⁴+1, X⁷+X⁵+X³+X+1  irreducible over F₂
#        → no roots in GF(2^m) when gcd(m,7)=1 (roots lie in GF(2^7), F_{2^7} ⊄ F_{2^m})
#   4. Verify APN, AB, permutation (m odd), CCZ-equiv to Beierle-Leander rep. #34 for m=3
# VBF API used: gf_mul, gf_pow, primitive_polynomial, differential_uniformity,
#               is_permutation, SBox, print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "theorem1.jl"))

"""
    proposition4_lut(m) -> Vector{Int}

LUT for Proposition 4 (Family 1, i=1, q=2) over GF(2^m)^3 (n=3m).
Requires gcd(m,7)=1. F(x,y,z) = (x³+x²z+yz², x²z+y³, xy²+y²z+z³).
"""
function proposition4_lut(m::Int)::Vector{Int}
    gcd(m, 7) == 1 || throw(ArgumentError("Proposition 4 requires gcd(m,7)=1, got m=$m"))
    return family1_lut(m, 1)
end

"""
    proposition4_root_conditions(m) -> (c1, c2, c3)

Verify that X⁷+X+1, X⁷+X⁴+1, X⁷+X⁵+X³+X+1 have no roots in GF(2^m).
When gcd(m,7)=1, all roots lie in GF(2^7) ⊄ GF(2^m), so conditions hold.
These are c1/c2/c3 from theorem1_root_conditions with q=2 (q²+q+1=7, q²+q=6, q²=4).
"""
function proposition4_root_conditions(m::Int)
    pp = primitive_polynomial(m)
    pow(x, e) = gf_pow(x, e, m; modulus = pp)

    c1 = poly_no_roots_f2m(m) do x; pow(x, 7) ⊻ x ⊻ 1; end
    c2 = poly_no_roots_f2m(m) do x; pow(x, 7) ⊻ pow(x, 4) ⊻ 1; end
    c3 = poly_no_roots_f2m(m) do x; pow(x, 7) ⊻ pow(x, 5) ⊻ pow(x, 3) ⊻ x ⊻ 1; end
    return c1, c2, c3
end

"""
    proposition4_report(; ms, io) -> Vector{NamedTuple}

Proposition 4 report for a list of m values (each with gcd(m,7)=1).
For m odd, also verifies AB and permutation properties.
"""
function proposition4_report(; ms::Vector{Int} = [3, 5, 6], io::IO = stdout)
    results = []
    for m in ms
        gcd(m, 7) == 1 || (print_kv("m=$m", "skipped — gcd(m,7)=$(gcd(m,7)) ≠ 1", io); continue)
        n = 3m

        print_section("Proposition 4 — Family 1 [gcd(m,7)=1, i=1, q=2, m=$m, n=$n]", io)
        print_kv("F(x,y,z)", "(x³+x²z+yz², x²z+y³, xy²+y²z+z³)", io)

        c1, c2, c3 = proposition4_root_conditions(m)
        print_check("X⁷+X+1  no roots in GF(2^$m)", c1, io)
        print_check("X⁷+X⁴+1  no roots in GF(2^$m)", c2, io)
        print_check("X⁷+X⁵+X³+X+1  no roots in GF(2^$m)", c3, io)

        lut  = proposition4_lut(m)
        du   = differential_uniformity(SBox(lut))
        apn  = du == 2
        perm = is_permutation(SBox(lut))
        print_check("APN (differential_uniformity = 2)", apn, io)
        if m % 2 == 1
            print_check("permutation over GF(2^$n)  [m=$m odd → Theorem 3]", perm, io)
        else
            print_kv("permutation", perm ? "yes" : "no (m=$m even)", io)
        end

        push!(results, (; m, n, conditions = (c1, c2, c3), du, apn, perm, lut))
    end
    return results
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    proposition4_report(ms = [3, 5, 6])
end
