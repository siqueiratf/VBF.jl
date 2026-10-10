# Implements Theorem 3: A new univariate quadratic APN family over F_{2^{3m}}
# Paper: Kangquan Li, Yue Zhou, Chunlei Li, Longjiang Qu (2022),
#        "Two New Families of Quadratic APN Functions",
#        IEEE Trans. Inf. Theory 68(7):4761–4769
# Section: IV — A New Family of APN Functions over F_{2^{3m}}
#
# Theorem 3: Let gcd(s, m) = 1 and v ∈ F*_{2^m}. Choose μ ∈ F*_{2^{3m}} such
# that μ^{2^{2m}+2^m+1} ≠ 1 and L(z) = z^{2^{m+s}} + μ·z^{2^s} + z permutes
# F_{2^{3m}}. Then f(z) = L(z)^{2^m+1} + v·z^{2^m+1} is APN over F_{2^{3m}}.
#
# Remark 1 (paper): Bartoli et al. proved that for m ≥ 3 with s = 1, a valid μ
# always exists. For m = 1 no valid μ exists (|F*_{2^3}| = 7 = norm_exp, so all
# elements satisfy μ^7 = 1). Exhaustive search at m=2,s=1 finds no admissible μ.
#
# Pseudocode:
#   1. Guard gcd(s, m) = 1.
#   2. Call find_valid_mu(m, s) to find smallest valid μ.
#   3. For each z ∈ F_{2^{3m}}:
#        Lz = z^{e_high} ⊕ μ·z^{e_low} ⊕ z   (e_high=2^{m+s}, e_low=2^s)
#        f(z) = Lz^{e_out} ⊕ v·z^{e_out}      (e_out=2^m+1)
#   4. Verify differential_uniformity = 2.
# VBF API used: gf_mul, gf_pow, primitive_polynomial, differential_uniformity,
#               algebraic_degree, SBox, print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

"""
    theorem3_sbox(m, s, μ, v; modulus) -> SBox{3m}

Build the SBox for Theorem 3's univariate APN family over GF(2^{3m}):
  f(z) = L(z)^{2^m+1} + v·z^{2^m+1}
where L(z) = z^{2^{m+s}} + μ·z^{2^s} + z.
Checks: gcd(s,m)=1, μ^{2^{2m}+2^m+1}≠1, L permutes GF(2^{3m}), v∈GF(2^m)*.
"""
function theorem3_sbox(m::Int, s::Int, μ::Int, v::Int;
                        modulus::Int = primitive_polynomial(3m))
    m >= 1 && s >= 1 && gcd(s, m) == 1 || throw(ArgumentError("requires m,s > 0 and gcd(s,m)=1"))
    n          = 3m
    0 < μ < (1 << n) || throw(ArgumentError("μ must be nonzero in GF(2^(3m))"))
    0 < v < (1 << n) || throw(ArgumentError("v must be nonzero in the embedded GF(2^m)"))
    gf_pow(v, 1 << m, n; modulus) == v || throw(ArgumentError("v is outside the embedded GF(2^m)"))
    norm_exp = (1 << (2m)) + (1 << m) + 1
    gf_pow(μ, norm_exp, n; modulus) != 1 || throw(ArgumentError("μ must have relative norm different from 1"))
    linear_lut = [gf_pow(z, 1 << mod(m+s,n), n; modulus) ⊻ gf_mul(μ, gf_pow(z,1 << mod(s, n),n;modulus),n;modulus) ⊻ z for z in 0:(1<<n)-1]
    length(unique(linear_lut)) == (1 << n) || throw(ArgumentError("L must permute GF(2^(3m))"))
    e_high     = 1 << mod(m + s, n)
    e_low      = 1 << mod(s, n)
    e_out      = (1 << m) + 1   # 2^m + 1 (Gold-type exponent)
    field_size = 1 << n

    pow(x, e) = gf_pow(x, e, n; modulus)
    mul(a, b) = gf_mul(a, b, n; modulus)

    lut = Vector{Int}(undef, field_size)
    for z in 0:(field_size - 1)
        Lz       = pow(z, e_high) ⊻ mul(μ, pow(z, e_low)) ⊻ z
        lut[z + 1] = pow(Lz, e_out) ⊻ mul(v, pow(z, e_out))
    end
    SBox{n}(lut)
end

"""
    theorem3_report([io]; ms, s, v) -> NamedTuple

For each m in ms: find the smallest valid μ (Theorem 3 conditions), build f, verify APN.
s = Frobenius exponent in L; gcd(s, m) = 1 required.
v = nonzero scalar factor; any v ∈ F*_{2^m} works (v=1 by default).
"""
function theorem3_report(io::IO = stdout;
                          ms::Vector{Int} = [2, 3],
                          s::Int           = 1,
                          v::Int           = 1)
    print_section("Theorem 3 — univariate APN over GF(2^{3m})", io)
    println(io, "  f(z) = L(z)^{2^m+1} + v·z^{2^m+1},  " *
                "L(z) = z^{2^{m+s}} + μ·z^{2^s} + z,  gcd(s,m)=1")
    print_kv("  s", s, io)
    print_kv("  v", v, io)

    all_ok  = true
    results = Dict{Int, NamedTuple}()

    for m in ms
        if gcd(s, m) != 1
            println(io, "  [SKIP] m=$m: gcd($s,$m)=$(gcd(s,m)) ≠ 1 — theorem does not apply")
            continue
        end

        μ, found = find_valid_mu(m, s)
        if !found
            println(io, "  [SKIP] m=$m: exhaustive search found no μ satisfying both the norm and L-permutation hypotheses")
            results[m] = (; μ = -1, found = false, apn = false)
            continue
        end

        F   = theorem3_sbox(m, s, μ, v)
        du  = differential_uniformity(F)
        deg = algebraic_degree(F)
        ok  = (du == 2)
        all_ok &= ok
        print_check("m=$m  n=$(3m)  diff-uniformity=2", ok, io)
        print_kv("    μ (first valid)", μ, io)
        print_kv("    algebraic-degree", deg, io)
        results[m] = (; μ, found, diff_uniformity = du, algebraic_degree = deg, apn = ok)
    end

    print_kv("completeness", "exhaustive (all elements checked)", io)
    return (; all_ok, results)
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem3_report()
end
