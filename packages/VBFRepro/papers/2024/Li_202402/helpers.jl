# Implements paper-local helpers for Li–Kaleyski (2024) reproduction.
# Paper: Li, Kaleyski (2024), "Two New Infinite Families of APN Functions in Trivariate Form"
# Section: General — trivariate encoding, root checkers, LUT construction
#
# Pseudocode:
#   1. Encode (x,y,z) ∈ F_{2^m}^3 as integer x·2^{2m} + y·2^m + z
#   2. Evaluate F(x,y,z) via gf_mul/gf_pow in GF(2^m)
#   3. Check polynomial root conditions over GF(2^m) and GF(2^m)^2
# VBF API used: gf_mul, gf_pow, primitive_polynomial, print_banner

using VBF

function print_header(io::IO = stdout)
    print_banner(io,
        "Li, Kaleyski (2024): Two New Infinite Families of APN Functions in Trivariate Form",
        "Cryptography and Communications (2024)")
end

"""
    split_triple(idx, m) -> (x, y, z)

Decode integer idx ∈ [0, 2^{3m}) as x·2^{2m} + y·2^m + z.
"""
function split_triple(idx::Int, m::Int)
    mask = (1 << m) - 1
    z = idx & mask
    y = (idx >> m) & mask
    x = (idx >> (2m)) & mask
    return x, y, z
end

"""
    join_triple(x, y, z, m) -> Int

Encode (x,y,z) ∈ [0,2^m)^3 as x·2^{2m} + y·2^m + z.
"""
join_triple(x::Int, y::Int, z::Int, m::Int) = (x << (2m)) | (y << m) | z

"""
    trivariate_lut(m, f) -> Vector{Int}

Build 2^{3m}-entry LUT from trivariate f(x,y,z) -> (fx,fy,fz) over GF(2^m).
"""
function trivariate_lut(m::Int, f::Function)::Vector{Int}
    N = 1 << (3m)
    lut = Vector{Int}(undef, N)
    for idx in 0:(N-1)
        x, y, z = split_triple(idx, m)
        fx, fy, fz = f(x, y, z)
        lut[idx+1] = join_triple(fx, fy, fz, m)
    end
    return lut
end

"""
    poly_no_roots_f2m(P, m) -> Bool

True iff P: GF(2^m) → GF(2^m) has no roots.
"""
function poly_no_roots_f2m(P::Function, m::Int)::Bool
    for x in 0:((1 << m) - 1)
        P(x) == 0 && return false
    end
    return true
end

"""
    bipoly_no_roots_f2m(P, m) -> Bool

True iff bivariate P(X,Y) has no roots in GF(2^m)^2.
"""
function bipoly_no_roots_f2m(P::Function, m::Int)::Bool
    Fm = 1 << m
    for x in 0:(Fm-1), y in 0:(Fm-1)
        P(x, y) == 0 && return false
    end
    return true
end
