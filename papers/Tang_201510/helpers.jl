# Shared utilities for Tang, Carlet, Tang (2015)
# Paper: Deng Tang, Claude Carlet, Xiaohu Tang (2015),
#        "Differentially 4-Uniform Bijections by Permuting the Inverse Function"
#        Designs, Codes and Cryptography, DOI 10.1007/s10623-015-0137-y
# Section: General — construction primitives and set builders
#
# VBF API used: gf_trace, gf_pow, linearity, differential_spectrum,
#               primitive_polynomial, SBox, print_banner

using VBF

function print_header(io::IO = stdout)
    print_banner(io,
        "Tang, Carlet, Tang (2015): Differentially 4-Uniform Bijections by Permuting the Inverse Function",
        "Designs, Codes and Cryptography, DOI 10.1007/s10623-015-0137-y")
end

# 0^{-1} = 0 convention used throughout the paper (Section 3)
function safe_inv(x::Int, n::Int; modulus::Int = primitive_polynomial(n))
    x == 0 && return 0
    gf_pow(x, (1 << n) - 2, n; modulus)
end

# U_max = { x in F*_{2^n} | tr1n(x^{-1}) = 1  AND  tr1n((x+1)^{-1}) = 1 }
# Indicator Eq.(7): delta_{U_max}(x) = tr(x^{-1}) * tr((x+1)^{-1})
function build_u_max(n::Int; modulus::Int = primitive_polynomial(n))
    [x for x in 1:((1 << n) - 1)
     if gf_trace(safe_inv(x, n; modulus), n; modulus) == 1 &&
        gf_trace(safe_inv(x ⊻ 1, n; modulus), n; modulus) == 1]
end

# U_{m0} = { x in U_max | tr1n(x) = 0 }   Indicator Eq.(8)
function build_u_m0(n::Int; modulus::Int = primitive_polynomial(n))
    [x for x in build_u_max(n; modulus) if gf_trace(x, n; modulus) == 0]
end

# U_{m1} = { x in U_max | tr1n(x) = 1 }   Indicator Eq.(9)
function build_u_m1(n::Int; modulus::Int = primitive_polynomial(n))
    [x for x in build_u_max(n; modulus) if gf_trace(x, n; modulus) == 1]
end

# U_max elements come in pairs {x, x+1} by condition a).
# Returns one representative tuple per pair.
function u_max_pairs(u_max::Vector{Int})
    pairs = Tuple{Int,Int}[]
    seen  = Set{Int}()
    for x in u_max
        x ∈ seen && continue
        push!(pairs, (x, x ⊻ 1))
        push!(seen, x)
        push!(seen, x ⊻ 1)
    end
    pairs
end

# Verify Construction 1 conditions on U:
# a) for any x in U, x+1 in U
# b) for any x in U, tr1n(x^{-1}) = 1
function validate_u(U::AbstractVector{<:Integer}, n::Int;
                    modulus::Int = primitive_polynomial(n))
    u_set = Set(Int.(U))
    for x in U
        (x ⊻ 1) ∈ u_set ||
            error("condition a) violated: x=$x but x⊕1=$(x ⊻ 1) ∉ U")
        gf_trace(safe_inv(x, n; modulus), n; modulus) == 1 ||
            error("condition b) violated: tr(x^{-1}) ≠ 1 for x=$x")
    end
    true
end

# F(x) = (x+1)^{-1} if x in U, x^{-1} otherwise  (0^{-1} = 0)
function construction1_sbox(n::Int, U::AbstractVector{<:Integer};
                             modulus::Int = primitive_polynomial(n))
    field_size = 1 << n
    u_set = Set(Int.(U))
    lut = Vector{Int}(undef, field_size)
    for x in 0:(field_size - 1)
        lut[x + 1] = safe_inv(x ⊻ (x ∈ u_set ? 1 : 0), n; modulus)
    end
    SBox{n}(lut)
end

# NL(F) = 2^{n-1} - linearity(F) / 2
function nonlinearity(F::SBox{N}) where N
    (1 << (N - 1)) - linearity(F) ÷ 2
end

# (D_0, D_2, D_4) from differential_spectrum (excludes trivial a=0 row)
# D_t = #{ (a,b) : a != 0, delta_F(a,b) = t }
function diff_spec_d024(F::SBox)
    sp = differential_spectrum(F)
    (get(sp, 0, 0), get(sp, 2, 0), get(sp, 4, 0))
end
