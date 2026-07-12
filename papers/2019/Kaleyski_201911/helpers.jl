# Implements paper-local helpers for the Kaleyski (2019) reproduction.
# Paper: Kaleyski, N. (2019), "Changing APN functions at two points",
#        arXiv:1911.02608 / Des. Codes Cryptogr. 88(8):1387–1416
# Section: General — shared helpers, normalisation, S1/S2 computation
#
# VBF API used: SBox, ddt, differential_uniformity, gf_inv, gf_mul,
#               primitive_polynomial, print_banner

using VBF

"""Print paper title, author, venue."""
print_header(io::IO = stdout) = print_banner(
    io,
    "Kaleyski (2019): Changing APN functions at two points",
    "arXiv:1911.02608 / Des. Codes Cryptogr. 88(8):1387–1416",
)

"""
    is_swap_degenerate(s::SBox, u1::Integer = 0, u2::Integer = 1) -> Bool

`true` when `F(u₁) == F(u₂)`, in which case the two-point swap at `{u₁,u₂}` is a
no-op (`G = F`) and Observation 7's hypothesis `F(u₁) ≠ F(u₂)` (i.e. `vᵢ ≠ 0`)
fails, so no EA-normalisation onto `F'(0)=0, F'(1)=1` exists *for that pair*.

Note this is a property of the **pair**, not of the function: a function with
`F(0) = F(1)` still has ~2^(2n−1) other pairs that admit a genuine swap. Use
[`genuine_pairs`](@ref) / [`first_genuine_pair`](@ref) to reach them.
"""
is_swap_degenerate(s::SBox, u1::Integer = 0, u2::Integer = 1) =
    Int(s.lut[Int(u1)+1]) == Int(s.lut[Int(u2)+1])

"""
    genuine_pairs(s::SBox{N}) -> Vector{Tuple{Int,Int}}

All pairs `(u₁,u₂)`, `u₁ < u₂`, with `F(u₁) ≠ F(u₂)` — exactly the pairs whose
two-point swap is not a no-op (Observation 7's precondition).
"""
function genuine_pairs(s::SBox{N}) where {N}
    q = 1 << N
    lut = Int.(s.lut)
    out = Tuple{Int,Int}[]
    for u1 = 0:q-2, u2 = (u1+1):q-1
        lut[u1+1] != lut[u2+1] && push!(out, (u1, u2))
    end
    return out
end

"""
    first_genuine_pair(s::SBox{N}) -> Tuple{Int,Int}

Lexicographically first `(u₁,u₂)` with `F(u₁) ≠ F(u₂)`. Exists for every
non-constant `F` (in particular for every APN function with `n ≥ 1`).
"""
function first_genuine_pair(s::SBox{N}) where {N}
    q = 1 << N
    lut = Int.(s.lut)
    for u1 = 0:q-2, u2 = (u1+1):q-1
        lut[u1+1] != lut[u2+1] && return (u1, u2)
    end
    throw(ArgumentError("first_genuine_pair: F is constant; no genuine swap exists"))
end

"""
    swap_points(s::SBox{N}, u1::Integer, u2::Integer) -> SBox{N}

`G` obtained from `F` by swapping the two values `F(u₁)` and `F(u₂)`; equivalently
`G(x) = F(x) + 1_{u₁}(x)·v + 1_{u₂}(x)·v` with `v = F(u₁) + F(u₂)`.
"""
function swap_points(s::SBox{N}, u1::Integer, u2::Integer) where {N}
    lut = Int.(s.lut)
    i, j = Int(u1) + 1, Int(u2) + 1
    lut[i], lut[j] = lut[j], lut[i]
    return SBox(lut)
end

"""
    normalize_apn(s::SBox{N}, u1::Integer = 0, u2::Integer = 1) -> SBox{N}

Observation 7 (Kaleyski 2019). Given `F` and a pair `u₁ ≠ u₂` with
`F(u₁) ≠ F(u₂)`, build the EA-equivalent representative

    F'(x) = ( F(A₂(x)) + F(u₁) ) / ( F(u₁) + F(u₂) ),   A₂(x) = x·(u₁+u₂) + u₁

which satisfies `F'(0) = 0` and `F'(1) = 1`. The paper's three affine maps are
all applied here: the input map `A₂` (bijective, `A₂(0)=u₁`, `A₂(1)=u₂`), the
output scaling `A₁(x) = x / (F(u₁)+F(u₂))`, and the output shift
`A(x) = x + F(u₁)/(F(u₁)+F(u₂))`.

Consequence (the reason `A₂` matters): swapping `F'` at `{0,1}` yields a function
EA-equivalent to swapping `F` at `{u₁,u₂}`. So Theorem 17 applied to
`normalize_apn(F, u₁, u₂)` decides whether `swap_points(F, u₁, u₂)` is APN — for
*every* pair, not just `(0,1)`. The default `(0,1)` makes `A₂` the identity and
reproduces the previous output-only normalisation exactly.

Throws `ArgumentError` if `u₁ == u₂` or `F(u₁) == F(u₂)` (degenerate pair — the
swap is a no-op and `A₁` is undefined). Pre-filter with
[`is_swap_degenerate`](@ref) or pick a pair with [`genuine_pairs`](@ref).
"""
function normalize_apn(s::SBox{N}, u1::Integer = 0, u2::Integer = 1) where {N}
    q = 1 << N
    a, b = Int(u1), Int(u2)
    (0 <= a < q && 0 <= b < q) ||
        throw(ArgumentError("normalize_apn: u1, u2 must lie in 0:$(q-1)"))
    a == b && throw(ArgumentError("normalize_apn: u1 == u2 ($a); need u1 ≠ u2"))
    lut = Int.(s.lut)
    fa, fb = lut[a+1], lut[b+1]
    fa == fb && throw(ArgumentError(
        "normalize_apn: F(u1) == F(u2) (degenerate pair u1=$a, u2=$b); the swap " *
        "is a no-op and Observation 7's A₁ is undefined. Filter with " *
        "is_swap_degenerate first."))
    d = xor(fa, fb)               # F(u₁) + F(u₂) ≠ 0
    dinv = gf_inv(d, N)           # A₁ scaling
    c = xor(a, b)                 # A₂(x) = x·(u₁+u₂) + u₁
    out = Vector{Int}(undef, q)
    @inbounds for x = 0:q-1
        y = xor(gf_mul(x, c, N), a)
        out[x+1] = gf_mul(xor(lut[y+1], fa), dinv, N)
    end
    return SBox(out)
end

"""
    power_exponent(s::SBox{N}) -> Union{Int,Nothing}

Mathematical test for "is `F` a power function `x^k`" over `GF(2ⁿ)` with the
canonical modulus `primitive_polynomial(N)` (so `g = 2` is a generator of the
multiplicative group). Returns `k` if `F(x) = x^k`, else `nothing`.

`F` is a monomial iff `F(0)=0`, `F(1)=1` and `F` is multiplicative on the
generator, i.e. `F(g·x) = F(g)·F(x)` for all `x` — then `F(gⁱ) = F(g)ⁱ` and
`k = log_g F(g)`. Cost `O(2ⁿ)`.

Paper-local because core VBF has no monomial predicate; see README's
library-reuse note (an `is_power_function` belongs in `packages/VBF/src/`).
"""
function power_exponent(s::SBox{N}) where {N}
    q = 1 << N
    lut = Int.(s.lut)
    (lut[1] == 0 && q > 1 && lut[2] == 1) || return nothing
    N == 1 && return 1
    g = 2                          # primitive modulus ⇒ x = 2 generates GF(2ⁿ)*
    fg = lut[g+1]
    fg == 0 && return nothing
    @inbounds for x = 0:q-1
        lut[gf_mul(g, x, N)+1] == gf_mul(fg, lut[x+1], N) || return nothing
    end
    acc = 1                        # discrete log of F(g) base g
    for k = 0:(q-2)
        acc == fg && return k == 0 ? q - 1 : k
        acc = gf_mul(acc, g, N)
    end
    return nothing
end

"""
    is_power_function(s::SBox) -> Bool

`true` iff `s` is a monomial `x^k` over `GF(2ⁿ)`; see [`power_exponent`](@ref).
"""
is_power_function(s::SBox) = power_exponent(s) !== nothing

"""
    compute_s1(s::SBox{N}) -> Int
    compute_s1(d::AbstractMatrix, s::SBox{N}) -> Int

S1(F) = Σ_y Δ_F(y, F(y) ⊕ 1).  Kaleyski (2019), Table 1.
Requires F(0)=0, F(1)=1 for use with Theorem 17.
The two-argument form reuses a DDT that the caller already built.
"""
function compute_s1(d::AbstractMatrix, s::SBox{N}) where {N}
    q = 1 << N
    total = 0
    @inbounds for y = 0:q-1
        b = xor(Int(s.lut[y+1]), 1)   # F(y) ⊕ 1
        total += d[y+1, b+1]           # Δ_F(y, F(y)⊕1)
    end
    return total
end
compute_s1(s::SBox) = compute_s1(ddt(s), s)

"""
    compute_s2(s::SBox{N}) -> Int
    compute_s2(d::AbstractMatrix, s::SBox{N}) -> Int

S2(F) = Σ_y Δ_F(y ⊕ 1, F(y)).  Kaleyski (2019), Table 1.
Requires F(0)=0, F(1)=1 for use with Theorem 17.
The two-argument form reuses a DDT that the caller already built.
"""
function compute_s2(d::AbstractMatrix, s::SBox{N}) where {N}
    q = 1 << N
    total = 0
    @inbounds for y = 0:q-1
        a = xor(y, 1)                  # y ⊕ 1
        b = Int(s.lut[y+1])            # F(y)
        total += d[a+1, b+1]           # Δ_F(y⊕1, F(y))
    end
    return total
end
compute_s2(s::SBox) = compute_s2(ddt(s), s)

"""
    theorem17_holds(s::SBox{N}) -> (s1, s2, dd10, holds)

Check Theorem 17 (Eq. 29): 6·Δ_F(1,0) = S1(F)+S2(F).
`s` must be normalised (F(0)=0, F(1)=1) — use [`normalize_apn`](@ref).
Returns (S1, S2, Δ_F(1,0), whether condition holds).

Theorem 17 is a **biconditional**: `holds` is `true` iff `swap_points(s, 0, 1)`
is APN. Both directions are exercised by the test suite (the n=4 case is the
positive one; every n ≥ 5 catalog case is negative).
"""
function theorem17_holds(s::SBox{N}) where {N}
    d = ddt(s)
    dd10 = Int(d[2, 1])    # Δ_F(1, 0): a=1, b=0
    s1 = compute_s1(d, s)
    s2 = compute_s2(d, s)
    holds = (6 * dd10 == s1 + s2)
    return (s1 = s1, s2 = s2, dd10 = dd10, holds = holds)
end

"""
    swap_is_apn(s::SBox, u1::Integer, u2::Integer) -> Bool

Ground truth for Theorem 17: build `G = swap_points(s, u1, u2)` and test
`differential_uniformity(G) == 2` directly, with no reference to Eq. 29.
"""
swap_is_apn(s::SBox, u1::Integer, u2::Integer) =
    differential_uniformity(swap_points(s, u1, u2)) == 2

"""
    formula34(n::Int) -> Int

Formula (34) from Kaleyski (2019): closed form for S1(x^3) = Σ_y Δ_{x^3}(y, y^3⊕1)
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
