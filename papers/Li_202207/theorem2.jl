# Implements Theorem 2: A new bivariate quadratic APN family over F_{2^{2m}}
# Paper: Kangquan Li, Yue Zhou, Chunlei Li, Longjiang Qu (2022),
#        "Two New Families of Quadratic APN Functions",
#        IEEE Trans. Inf. Theory 68(7):4761–4769
# Section: III — A New Family of APN Functions over F_{2^{2m}}^2
#
# Theorem 2: Let m be a positive integer with gcd(3, m) = 1. Then the function
#   f(x, y) = (x³ + xy² + y³ + xy,  x⁵ + x⁴y + y⁵ + xy + x²y²)
# is APN over F_{2^m}² ≅ F_{2^{2m}}.
#
# Pseudocode:
#   1. Guard gcd(3, m) = 1.
#   2. For each (x,y) ∈ GF(2^m)²:
#        f₁(x,y) = x³ + x·y² + y³ + x·y          (all arithmetic in GF(2^m))
#        f₂(x,y) = x⁵ + x⁴·y + y⁵ + x·y + x²·y²
#   3. Encode via bivariate_lut (index = x|(y<<m), value = f₁|(f₂<<m)).
#   4. Verify differential_uniformity = 2.
# VBF API used: gf_mul, gf_pow, primitive_polynomial, differential_uniformity,
#               algebraic_degree, SBox, print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

"""
    theorem2_sbox(m; modulus) -> SBox{2m}

Build the SBox for Theorem 2's bivariate APN family over GF(2^m)²:
  f(x,y) = (x³ + xy² + y³ + xy,  x⁵ + x⁴y + y⁵ + xy + x²y²)
Requires gcd(3, m) = 1.
"""
function theorem2_sbox(m::Int; modulus::Int = primitive_polynomial(m))
    m >= 2 || error("Theorem 2: m=1 is the trivial field GF(2); VBF gf_mul requires n≥2")
    gcd(3, m) == 1 || error("Theorem 2 requires gcd(3, m) = 1, got m = $m (gcd = $(gcd(3,m)))")
    pow(x, e) = gf_pow(x, e, m; modulus)
    mul(a, b) = gf_mul(a, b, m; modulus)

    f1(x, y) = pow(x, 3) ⊻ mul(x, pow(y, 2)) ⊻ pow(y, 3) ⊻ mul(x, y)
    f2(x, y) = pow(x, 5) ⊻ mul(pow(x, 4), y) ⊻ pow(y, 5) ⊻ mul(x, y) ⊻
               mul(pow(x, 2), pow(y, 2))

    bivariate_lut(m, f1, f2; modulus)
end

"""
    theorem2_report([io]; ms) -> NamedTuple

Verify Theorem 2 APN for each m in ms (all with gcd(3, m) = 1 checked).
Prints structured output using VBF report emitters.
"""
function theorem2_report(io::IO = stdout; ms::Vector{Int} = [2, 4])
    print_section("Theorem 2 — bivariate APN over GF(2^{2m})", io)
    println(io, "  f(x,y) = (x³+xy²+y³+xy,  x⁵+x⁴y+y⁵+xy+x²y²),  gcd(3,m)=1")

    all_ok  = true
    results = Dict{Int, NamedTuple}()

    for m in ms
        if gcd(3, m) != 1
            println(io, "  [SKIP] m=$m: gcd(3,$m)=$(gcd(3,m)) ≠ 1 — theorem does not apply")
            continue
        end
        F  = theorem2_sbox(m)
        du = differential_uniformity(F)
        deg = algebraic_degree(F)
        ok  = (du == 2)
        all_ok &= ok
        print_check("m=$m  n=$(2m)  diff-uniformity=2", ok, io)
        print_kv("    algebraic-degree", deg, io)
        results[m] = (; diff_uniformity = du, algebraic_degree = deg, apn = ok)
    end

    print_kv("completeness", "exhaustive (all elements checked)", io)
    return (; all_ok, results)
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem2_report()
end
