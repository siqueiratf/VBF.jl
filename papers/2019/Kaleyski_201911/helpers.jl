# Implements paper-local helpers for the Kaleyski (2019) reproduction.
# Paper: Kaleyski, N. (2019), "Changing APN functions at two points",
#        arXiv:1911.02608 / Des. Codes Cryptogr. 88(8):1387–1416
# Section: General — shared helpers, normalisation, S1/S2 computation
#
# VBF API used: SBox, ddt, gf_inv, gf_mul, primitive_polynomial

using VBF

"""Print paper title, author, venue."""
function print_header(io::IO = stdout)
    println(io, "=" ^ 72)
    println(io, "Kaleyski (2019): Changing APN functions at two points")
    println(io, "arXiv:1911.02608 / Des. Codes Cryptogr. 88(8):1387–1416")
    println(io, "=" ^ 72)
end

"""
    is_swap_degenerate(s::SBox) -> Bool

`true` when `F(0) == F(1)`, in which case the two-point swap at {0,1} is a no-op
(`G = F`) and Theorem 17's `F(1)=1` normalisation hypothesis cannot be met. The
paper excludes this via Observation 7 (`F(u₁) ≠ F(u₂)`, i.e. `v_i ≠ 0`); such
functions must be filtered out before calling `normalize_apn`/`theorem17_holds`.
"""
is_swap_degenerate(s::SBox) = Int(s.lut[1]) == Int(s.lut[2])

"""
    normalize_apn(s::SBox{N}) -> SBox{N}

EA-normalize `s` to satisfy F(0)=0, F(1)=1:
  1. XOR all outputs with F(0)  [output shift → F(0)=0]
  2. Multiply all outputs by gf_inv(F(1), N)  [output field-scaling → F(1)=1]

Required by Theorem 17 (Eq. 29). Power APN functions already satisfy both
conditions automatically (0^k=0, 1^k=1 in any field).

Throws `ArgumentError` if `F(0) == F(1)` (degenerate): no output-only transform
can yield `F(1)=1` there, and the two-point swap at {0,1} is a no-op. Pre-filter
with [`is_swap_degenerate`](@ref).
"""
function normalize_apn(s::SBox{N}) where {N}
    lut = Int.(s.lut)
    v0 = lut[1]           # F(0)
    lut = xor.(lut, v0)   # step 1: F(0) = 0
    v1 = lut[2]           # F(1) after shift
    v1 == 0 && throw(ArgumentError(
        "normalize_apn: F(0) == F(1) (degenerate); no output transform yields " *
        "F(1)=1. Filter with is_swap_degenerate first."))
    if v1 != 1
        inv_v1 = gf_inv(v1, N)
        lut = [gf_mul(y, inv_v1, N) for y in lut]
    end
    return SBox(lut)
end

"""
    compute_s1(s::SBox{N}) -> Int

S1(F) = Σ_y DD_F(y, F(y) ⊕ 1).  Kaleyski (2019), Table 1.
Requires F(0)=0, F(1)=1 for use with Theorem 17.
"""
function compute_s1(s::SBox{N}) where {N}
    d = ddt(s)
    q = 1 << N
    total = 0
    for y in 0:q-1
        b = xor(Int(s.lut[y+1]), 1)   # F(y) ⊕ 1
        total += d[y+1, b+1]           # DD_F(y, F(y)⊕1)
    end
    return total
end

"""
    compute_s2(s::SBox{N}) -> Int

S2(F) = Σ_y DD_F(y ⊕ 1, F(y)).  Kaleyski (2019), Table 1.
Requires F(0)=0, F(1)=1 for use with Theorem 17.
"""
function compute_s2(s::SBox{N}) where {N}
    d = ddt(s)
    q = 1 << N
    total = 0
    for y in 0:q-1
        a = xor(y, 1)                  # y ⊕ 1
        b = Int(s.lut[y+1])            # F(y)
        total += d[a+1, b+1]           # DD_F(y⊕1, F(y))
    end
    return total
end

"""
    theorem17_holds(s::SBox{N}) -> (s1, s2, dd10, holds)

Check Theorem 17 (Eq. 29): 6·DD_F(1,0) = S1(F)+S2(F).
`s` must be normalised (F(0)=0, F(1)=1).
Returns (S1, S2, DD_F(1,0), whether condition holds).
"""
function theorem17_holds(s::SBox{N}) where {N}
    d = ddt(s)
    dd10 = d[2, 1]         # DD_F(1, 0): a=1, b=0
    s1 = compute_s1(s)
    s2 = compute_s2(s)
    holds = (6 * dd10 == s1 + s2)
    return (s1 = s1, s2 = s2, dd10 = dd10, holds = holds)
end

"""
    formula34(n::Int) -> Int

Formula (34) from Kaleyski (2019): closed form for S1(x^3) = Σ_y DD_{x^3}(y, y^3⊕1)
as a function of the parity of `n` (and of `n/2`). Also equals S2(x^3).
"""
function formula34(n::Int)::Int
    if isodd(n)
        return 2 * (2^(n-1) - 1)
    elseif isodd(n ÷ 2)   # n even, n/2 odd
        return 2 * (2^(n-1) + 2^(n÷2) - 1)
    else                   # n even, n/2 even
        return 2 * (2^(n-1) - 2^(n÷2) - 1)
    end
end
