# Implements paper-local helpers for the Bracken–Byrne–Markin–McGuire (2008) reproduction.
# Paper: Bracken, Byrne, Markin, McGuire (2008),
#        "New Families of Quadratic Almost Perfect Nonlinear Trinomials and Multinomials",
#        Finite Fields and Their Applications 14 (2008), 703–714
# Section: General — field utilities, LUT builders, report formatting
#
# Pseudocode:
#   family1_lut(k, s, b, c, r):
#     1. n = 2k
#     2. exponents: e1=2^s+1, e2=2^{k+s}+2^k, e3=2^k+1, ei=2^{i+k}+2^i
#     3. LUT[x] = b·x^{e1} ⊕ b^{2^k}·x^{e2} ⊕ c·x^{e3} ⊕ Σ_{i=1}^{k-1} r[i]·x^{ei}
#   family2_lut(k, s, u, v):
#     1. n = 3k; 2^{-k} ≡ 2^{n-k} (mod 2^n−1)
#     2. exponents: e1=2^{n-k}+2^{k+s}, e2=2^s+1, e3=2^{k+s}+2^s
#     3. LUT[x] = u·x^{e1} ⊕ u^{2^k}·x^{e2} ⊕ v·x^{e3}
# VBF API used: gf_pow, gf_mul, gf_trace, gf_is_dth_power, in_subfield,
#               walsh_transform, primitive_polynomial, SBox

using VBF

"""
    trace_component_is_bent(F, v; modulus) -> Bool

True if x ↦ Tr(v·F(x)) is a bent Boolean function (N even),
where Tr is the absolute trace GF(2^N)→F₂ and · is GF multiplication.

TODO: not a clean drop-in for core `bent_components(F)`. `bent_components`
returns output masks `b` for the dot-product component `x ↦ ⟨b, F(x)⟩`, whereas
here the component is the trace form `x ↦ Tr(v·F(x))`. Trace forms and
dot-product forms are related by the (basis-dependent) dual-basis change
`⟨b, y⟩ = Tr(v·y)`, so `v ∈ bent_components(F)` is *not* equivalent to this
predicate without first mapping `v → b`. Kept explicit to test each specific
`v ∈ GF(2^k)*` as the paper states it.
"""
function trace_component_is_bent(F::SBox, v::Int;
                                   modulus::Int = primitive_polynomial(trailing_zeros(length(F.lut))))::Bool
    N = trailing_zeros(length(F.lut))
    n = 1 << N
    g = [gf_trace(gf_mul(v, F.lut[x+1], N; modulus), N; modulus)
         for x in 0:n-1]
    wt = walsh_transform(g)
    all(w^2 == n for w in wt)
end

"""
    is_primitive_element(x, n; modulus) -> Bool

True if `x` generates GF(2^n)*, i.e. its multiplicative order is exactly
`2^n − 1`. Tested via `x^{(2^n−1)/p} ≠ 1` for every prime `p | 2^n − 1`.
`0` and `1` are never primitive (for `n ≥ 2`).
"""
function is_primitive_element(x::Int, n::Int;
                              modulus::Int = primitive_polynomial(n))::Bool
    x == 0 && return false
    order = (1 << n) - 1
    order == 1 && return x == 1
    for p in _prime_divisors(order)
        gf_pow(x, order ÷ p, n; modulus) == 1 && return false
    end
    true
end

# Distinct prime divisors of `m ≥ 1`, by trial division (m ≤ 2^24 here).
function _prime_divisors(m::Int)::Vector{Int}
    ps, d = Int[], 2
    while d * d ≤ m
        if m % d == 0
            push!(ps, d)
            while m % d == 0
                m ÷= d
            end
        end
        d += 1
    end
    m > 1 && push!(ps, m)
    ps
end

"""
    family1_validate(k, s, b, c, r; modulus)

Throw `ArgumentError` unless the Theorem 1 hypotheses hold: `k`, `s` both odd,
`gcd(k,s)=1`, `b` not a cube in GF(2^{2k}), `c ∉ GF(2^k)`, `r[i] ∈ GF(2^k)`
and at most `k−1` coefficients `r[i]` (longer vectors would be silently
truncated by the term loop).

Every hypothesis is necessary: dropping any one of them yields instances that
are provably not APN — see `theorem1_necessity_report`.
"""
function family1_validate(k::Int, s::Int, b::Int, c::Int, r::AbstractVector{<:Integer};
                          modulus::Int = primitive_polynomial(2k))
    n = 2k
    (isodd(k) && isodd(s)) || throw(ArgumentError(
        "family1_lut: Theorem 1 requires k and s both odd, got k=$k, s=$s"))
    gcd(k, s) == 1 || throw(ArgumentError(
        "family1_lut: Theorem 1 requires gcd(k,s)=1, got gcd($k,$s)=$(gcd(k, s))"))
    gf_is_dth_power(b, 3, n; modulus) && throw(ArgumentError(
        "family1_lut: b=$b must not be a cube in GF(2^$n)"))
    in_subfield(c, k, n; modulus) && throw(ArgumentError(
        "family1_lut: c=$c must not lie in the subfield GF(2^$k)"))
    length(r) ≤ k - 1 || throw(ArgumentError(
        "family1_lut: r has $(length(r)) entries but only k−1 = $(k - 1) are used"))
    for (i, ri) in pairs(r)
        in_subfield(ri, k, n; modulus) || throw(ArgumentError(
            "family1_lut: r[$i]=$ri must lie in the subfield GF(2^$k)"))
    end
    nothing
end

"""
    family1_lut(k, s, b, c, r; modulus, validate = true) -> Vector{Int}

LUT for Theorem 1 (Family 1) on K = GF(2^{2k}):

    F(x) = b·x^{2^s+1} + b^{2^k}·x^{2^{k+s}+2^k} + c·x^{2^k+1}
           + Σ_{i=1}^{k−1} r[i]·x^{2^{i+k}+2^i}

APN conditions: k and s both odd, gcd(k,s)=1, c ∉ GF(2^k),
b not a cube in GF(2^{2k}), r[i] ∈ GF(2^k).
Setting r=[] or all r[i]=0 gives the trinomial subfamily.

The hypotheses are checked by [`family1_validate`](@ref) and violations raise
`ArgumentError`. `validate = false` skips the check; it exists only so that
(a) the necessity of each hypothesis can be *demonstrated* and (b) Theorem 4,
whose hypotheses are strictly weaker (no condition on `b`), can reuse the same
term loop. Do not use it to build "APN" functions.
"""
function family1_lut(k::Int, s::Int, b::Int, c::Int, r::Vector{Int} = Int[];
                     modulus::Int = primitive_polynomial(2k),
                     validate::Bool = true)::Vector{Int}
    validate && family1_validate(k, s, b, c, r; modulus)
    n   = 2k
    e1  = (1 << s) + 1
    e2  = (1 << (k + s)) + (1 << k)
    e3  = (1 << k) + 1
    b2k = gf_pow(b, 1 << k, n; modulus)
    lut = Vector{Int}(undef, 1 << n)
    for x in 0:(1 << n) - 1
        v  = gf_mul(b,   gf_pow(x, e1, n; modulus), n; modulus)
        v ⊻= gf_mul(b2k, gf_pow(x, e2, n; modulus), n; modulus)
        v ⊻= gf_mul(c,   gf_pow(x, e3, n; modulus), n; modulus)
        for i in 1:min(length(r), k - 1)
            v ⊻= gf_mul(r[i], gf_pow(x, (1 << (i + k)) + (1 << i), n; modulus), n; modulus)
        end
        lut[x + 1] = v
    end
    lut
end

"""
    family2_validate(k, s, u, v; modulus)

Throw `ArgumentError` unless the Theorem 3 hypotheses hold: `gcd(s,3k)=1`,
`k ≢ 0 mod 3`, `k+s ≡ 0 mod 3`, `u` primitive in GF(2^{3k}) and `v ∈ GF(2^k)`.

Every hypothesis is necessary — see `theorem3_necessity_report`.
"""
function family2_validate(k::Int, s::Int, u::Int, v::Int;
                          modulus::Int = primitive_polynomial(3k))
    n = 3k
    gcd(s, n) == 1 || throw(ArgumentError(
        "family2_lut: Theorem 3 requires gcd(s,3k)=1, got gcd($s,$n)=$(gcd(s, n))"))
    k % 3 == 0 && throw(ArgumentError(
        "family2_lut: Theorem 3 requires k ≢ 0 mod 3, got k=$k"))
    (k + s) % 3 == 0 || throw(ArgumentError(
        "family2_lut: Theorem 3 requires k+s ≡ 0 mod 3, got k+s=$(k + s)"))
    is_primitive_element(u, n; modulus) || throw(ArgumentError(
        "family2_lut: u=$u must be primitive in GF(2^$n)"))
    in_subfield(v, k, n; modulus) || throw(ArgumentError(
        "family2_lut: v=$v must lie in the subfield GF(2^$k)"))
    nothing
end

"""
    family2_lut(k, s, u, v; modulus, validate = true) -> Vector{Int}

LUT for Theorem 3 (Family 2) on F = GF(2^{3k}):

    F(x) = u·x^{2^{n−k}+2^{k+s}} + u^{2^k}·x^{2^s+1} + v·x^{2^{k+s}+2^s}

where n = 3k and 2^{−k} ≡ 2^{n−k} (mod 2^n−1).
APN conditions: gcd(s,3k)=1, k ≢ 0 mod 3, k+s ≡ 0 mod 3,
u primitive in GF(2^{3k}), v ∈ GF(2^k).
Setting v=0 gives the binomial subfamily from [Budaghyan-Carlet-Felke-Leander 2006].

The hypotheses are checked by [`family2_validate`](@ref) and violations raise
`ArgumentError`; `validate = false` skips the check and exists only to
demonstrate that each hypothesis is necessary.
"""
function family2_lut(k::Int, s::Int, u::Int, v::Int;
                     modulus::Int = primitive_polynomial(3k),
                     validate::Bool = true)::Vector{Int}
    validate && family2_validate(k, s, u, v; modulus)
    n   = 3k
    e1  = (1 << (n - k)) + (1 << (k + s))
    e2  = (1 << s) + 1
    e3  = (1 << (k + s)) + (1 << s)
    u2k = gf_pow(u, 1 << k, n; modulus)
    [gf_mul(u,   gf_pow(x, e1, n; modulus), n; modulus) ⊻
     gf_mul(u2k, gf_pow(x, e2, n; modulus), n; modulus) ⊻
     gf_mul(v,   gf_pow(x, e3, n; modulus), n; modulus)
     for x in 0:(1 << n) - 1]
end
