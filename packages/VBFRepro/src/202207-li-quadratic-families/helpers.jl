# Implements shared helpers for the Li et al. (2022) reproduction.
# Paper: Kangquan Li, Yue Zhou, Chunlei Li, Longjiang Qu (2022),
#        "Two New Families of Quadratic APN Functions",
#        IEEE Trans. Inf. Theory 68(7):4761–4769
# Section: General — bivariate LUT builder, μ search for Theorem 3, report header
#
# Pseudocode (bivariate_lut):
#   For each (x,y) ∈ GF(2^m)²:
#     1. Evaluate f₁(x,y), f₂(x,y) in GF(2^m)
#     2. Encode index = x | (y << m), value = f₁ | (f₂ << m)
#   Coordinate-wise XOR = GF(2^m)² addition → differential_uniformity works directly.
# VBF API used: gf_mul, gf_pow, primitive_polynomial, SBox, print_banner

using VBF

function print_header(io::IO = stdout)
    print_banner(io,
        "Li, Zhou, Li, Qu (2022): Two New Families of Quadratic APN Functions",
        "IEEE Trans. Inf. Theory, Vol. 68, No. 7, pp. 4761–4769, July 2022")
end

"""
    bivariate_lut(m, f1, f2; modulus) -> SBox{2m}

Build a bivariate SBox over GF(2^m)² from coordinate functions f1(x,y) and f2(x,y).
Encoding: index = x | (y << m), value = f1(x,y) | (f2(x,y) << m).
Coordinate-wise XOR equals GF(2^m)² addition, so `differential_uniformity` works directly.
"""
function bivariate_lut(m::Int, f1::Function, f2::Function;
                        modulus::Int = primitive_polynomial(m))
    n   = 2m
    len = 1 << m
    lut = Vector{Int}(undef, 1 << n)
    for x in 0:(len - 1)
        for y in 0:(len - 1)
            lut[(x | (y << m)) + 1] = f1(x, y) | (f2(x, y) << m)
        end
    end
    SBox{n}(lut)
end

"""
    find_valid_mu(m, s; modulus) -> (μ::Int, found::Bool)

Find the smallest μ ∈ F*_{2^{3m}} satisfying (Theorem 3 conditions):
  (i)  μ^{2^{2m}+2^m+1} ≠ 1   (μ not in kernel of the relative norm N_{F_{3m}/F_m})
  (ii) L(z) = z^{2^{m+s}} + μ·z^{2^s} + z is a permutation of F_{2^{3m}}

gcd(s, m) = 1 is required. Returns (-1, false) when no valid μ exists (e.g. m=1,
where |F*_{2^3}|=7 divides norm_exp=7, so all elements have norm 1).
Precomputes z^{e_high} and z^{e_low} for all z to amortise Frobenius cost.
"""
function find_valid_mu(m::Int, s::Int; modulus::Int = primitive_polynomial(3m))
    m >= 1 && s >= 1 && gcd(s, m) == 1 || throw(ArgumentError("requires m,s > 0 and gcd(s,m)=1"))
    n          = 3m
    norm_exp   = (1 << (2m)) + (1 << m) + 1
    e_high     = 1 << mod(m + s, n)
    e_low      = 1 << mod(s, n)
    field_size = 1 << n

    pow(x, e) = gf_pow(x, e, n; modulus)
    mul(a, b) = gf_mul(a, b, n; modulus)

    high_pow = [pow(z, e_high) for z in 0:(field_size - 1)]
    low_pow  = [pow(z, e_low)  for z in 0:(field_size - 1)]

    for μ in 1:(field_size - 1)
        pow(μ, norm_exp) == 1 && continue
        seen    = fill(false, field_size)
        is_perm = true
        for z in 0:(field_size - 1)
            Lz = high_pow[z + 1] ⊻ mul(μ, low_pow[z + 1]) ⊻ z
            if seen[Lz + 1]
                is_perm = false
                break
            end
            seen[Lz + 1] = true
        end
        is_perm && return (μ, true)
    end
    return (-1, false)
end
