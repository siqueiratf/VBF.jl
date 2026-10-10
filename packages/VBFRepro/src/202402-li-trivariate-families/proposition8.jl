# Implements Section 4: Proposition 8 — explicit APN permutation for gcd(m,7)=1
# Paper: Li, Kaleyski (2024), "Two New Infinite Families of APN Functions in Trivariate Form"
# Section: 4 — Proposition 8 (i=1, q=2, gcd(m,7)=1)
#
# Pseudocode:
#   1. Set i=1, q=2; check gcd(m,7)=1
#   2. F(x,y,z) = (x³+xy²+yz², xy²+z³, x²z+y³+y²z)   (Family 2, q=2)
#   3. Sufficient conditions reduce to:
#        X⁷+X³+X²+X+1, X⁷+X⁴+1, X⁷+X+1  irreducible over F₂
#        → no roots in GF(2^m) when gcd(m,7)=1
#   4. Verify APN, AB, permutation (m odd), CCZ-equiv to Beierle-Leander rep. #35 for m=3
# VBF API used: gf_mul, gf_pow, primitive_polynomial, differential_uniformity,
#               is_permutation, SBox, print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "theorem6.jl"))

"""
    proposition8_lut(m) -> Vector{Int}

LUT for Proposition 8 (Family 2, i=1, q=2) over GF(2^m)^3 (n=3m).
Requires gcd(m,7)=1. F(x,y,z) = (x³+xy²+yz², xy²+z³, x²z+y³+y²z).
"""
function proposition8_lut(m::Int)::Vector{Int}
    gcd(m, 7) == 1 || throw(ArgumentError("Proposition 8 requires gcd(m,7)=1, got m=$m"))
    return family2_lut(m, 1)
end

"""
    proposition8_root_conditions(m) -> (c1, c2, c3)

Verify that X⁷+X³+X²+X+1, X⁷+X⁴+1, X⁷+X+1 have no roots in GF(2^m).
When gcd(m,7)=1, roots lie in GF(2^7) ⊄ GF(2^m).
"""
function proposition8_root_conditions(m::Int)
    pp = primitive_polynomial(m)
    pow(x, e) = gf_pow(x, e, m; modulus = pp)

    c1 = poly_no_roots_f2m(m) do x
        pow(x, 7) ⊻ pow(x, 3) ⊻ pow(x, 2) ⊻ x ⊻ 1
    end
    c2 = poly_no_roots_f2m(m) do x; pow(x, 7) ⊻ pow(x, 4) ⊻ 1; end
    c3 = poly_no_roots_f2m(m) do x; pow(x, 7) ⊻ x ⊻ 1; end
    return c1, c2, c3
end

"""
    proposition8_report(; ms, io) -> Vector{NamedTuple}

Proposition 8 report for a list of m values (each with gcd(m,7)=1).
"""
function proposition8_report(; ms::Vector{Int} = [3, 5, 6], io::IO = stdout)
    results = []
    for m in ms
        gcd(m, 7) == 1 || (print_kv("m=$m", "skipped — gcd(m,7)=$(gcd(m,7)) ≠ 1", io); continue)
        n = 3m

        print_section("Proposition 8 — Family 2 [gcd(m,7)=1, i=1, q=2, m=$m, n=$n]", io)
        print_kv("F(x,y,z)", "(x³+xy²+yz², xy²+z³, x²z+y³+y²z)", io)

        c1, c2, c3 = proposition8_root_conditions(m)
        print_check("X⁷+X³+X²+X+1  no roots in GF(2^$m)", c1, io)
        print_check("X⁷+X⁴+1  no roots in GF(2^$m)", c2, io)
        print_check("X⁷+X+1  no roots in GF(2^$m)", c3, io)

        lut  = proposition8_lut(m)
        du   = differential_uniformity(SBox(lut))
        apn  = du == 2
        perm = is_permutation(SBox(lut))
        print_check("APN (differential_uniformity = 2)", apn, io)
        if m % 2 == 1
            print_check("permutation over GF(2^$n)  [m=$m odd → Theorem 7]", perm, io)
        else
            print_kv("permutation", perm ? "yes" : "no (m=$m even)", io)
        end

        push!(results, (; m, n, conditions = (c1, c2, c3), du, apn, perm, lut))
    end
    return results
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    proposition8_report(ms = [3, 5, 6])
end
