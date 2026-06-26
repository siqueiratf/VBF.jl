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
# VBF API used: gf_pow, gf_mul, primitive_polynomial, SBox

using VBF

function print_header(io::IO = stdout)
    println(io, "=" ^ 72)
    println(io, "Bracken, Byrne, Markin, McGuire (2008):")
    println(io, "New Families of Quadratic APN Trinomials and Multinomials")
    println(io, "Finite Fields and Their Applications 14 (2008), 703–714")
    println(io, "=" ^ 72)
end

"""
    gf_in_subfield(x, n, k; modulus) -> Bool

True if x ∈ GF(2^k) ⊆ GF(2^n), tested via x^{2^k} = x.
Requires k | n.
"""
function gf_in_subfield(x::Int, n::Int, k::Int;
                         modulus::Int = primitive_polynomial(n))::Bool
    gf_pow(x, 1 << k, n; modulus) == x
end

"""
    gf_is_cube(x, n; modulus) -> Bool

True if x is a cube in GF(2^n)*. By convention, 0 is a cube.
Requires 3 | (2^n − 1), i.e. n even.
Tests x^{(2^n−1)/3} == 1.
"""
function gf_is_cube(x::Int, n::Int;
                     modulus::Int = primitive_polynomial(n))::Bool
    x == 0 && return true
    m = (1 << n) - 1
    m % 3 == 0 ||
        throw(ArgumentError("gf_is_cube: 3 must divide 2^n−1; need n even, got n=$n"))
    gf_pow(x, m ÷ 3, n; modulus) == 1
end

"""
    gf_is_seventh_power(x, n; modulus) -> Bool

True if x is a seventh power in GF(2^n)*. By convention, 0 is a seventh power.
When 7 ∤ (2^n−1) the 7th-power map is bijective, so every element is a seventh power.
"""
function gf_is_seventh_power(x::Int, n::Int;
                               modulus::Int = primitive_polynomial(n))::Bool
    x == 0 && return true
    m = (1 << n) - 1
    m % 7 != 0 && return true   # 7∤(2^n−1) → bijective → all elements are 7th powers
    gf_pow(x, m ÷ 7, n; modulus) == 1
end

"""
    gf_absolute_trace(y, N; modulus) -> Int

Absolute trace Tr: GF(2^N) → F₂.
Tr(y) = y ⊕ y² ⊕ y⁴ ⊕ … ⊕ y^{2^{N−1}} ∈ {0, 1}.
"""
function gf_absolute_trace(y::Int, N::Int;
                             modulus::Int = primitive_polynomial(N))::Int
    reduce(⊻, (gf_pow(y, 1 << j, N; modulus) for j in 0:N-1))
end

"""
    trace_component_is_bent(F, v; modulus) -> Bool

True if x ↦ Tr(v·F(x)) is a bent Boolean function (N even),
where Tr is the absolute trace GF(2^N)→F₂ and · is GF multiplication.
"""
function trace_component_is_bent(F::SBox, v::Int;
                                   modulus::Int = primitive_polynomial(trailing_zeros(length(F.lut))))::Bool
    N = trailing_zeros(length(F.lut))
    n = 1 << N
    g = [gf_absolute_trace(gf_mul(v, F.lut[x+1], N; modulus), N; modulus)
         for x in 0:n-1]
    wt = walsh_transform(g)
    all(w^2 == n for w in wt)
end

"""
    gf_subfield_nonzero_elements(n, k; modulus) -> Vector{Int}

Nonzero elements of GF(2^k) embedded in GF(2^n) (requires k | n).
Returns {ω^{i·step} : i = 0 .. 2^k−2} where step = (2^n−1)/(2^k−1) and ω = 2.
"""
function gf_subfield_nonzero_elements(n::Int, k::Int;
                                       modulus::Int = primitive_polynomial(n))::Vector{Int}
    step = ((1 << n) - 1) ÷ ((1 << k) - 1)
    [gf_pow(2, i * step, n; modulus) for i in 0:((1 << k) - 2)]
end

"""
    family1_lut(k, s, b, c, r; modulus) -> Vector{Int}

LUT for Theorem 1 (Family 1) on K = GF(2^{2k}):

    F(x) = b·x^{2^s+1} + b^{2^k}·x^{2^{k+s}+2^k} + c·x^{2^k+1}
           + Σ_{i=1}^{k−1} r[i]·x^{2^{i+k}+2^i}

APN conditions: k and s both odd, gcd(k,s)=1, c ∉ GF(2^k),
b not a cube in GF(2^{2k}), r[i] ∈ GF(2^k).
Setting r=[] or all r[i]=0 gives the trinomial subfamily.
"""
function family1_lut(k::Int, s::Int, b::Int, c::Int, r::Vector{Int} = Int[];
                     modulus::Int = primitive_polynomial(2k))::Vector{Int}
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
    family2_lut(k, s, u, v; modulus) -> Vector{Int}

LUT for Theorem 3 (Family 2) on F = GF(2^{3k}):

    F(x) = u·x^{2^{n−k}+2^{k+s}} + u^{2^k}·x^{2^s+1} + v·x^{2^{k+s}+2^s}

where n = 3k and 2^{−k} ≡ 2^{n−k} (mod 2^n−1).
APN conditions: gcd(s,3k)=1, k ≢ 0 mod 3, k+s ≡ 0 mod 3,
u primitive in GF(2^{3k}), v ∈ GF(2^k).
Setting v=0 gives the binomial subfamily from [Budaghyan-Carlet-Felke-Leander 2006].
"""
function family2_lut(k::Int, s::Int, u::Int, v::Int;
                     modulus::Int = primitive_polynomial(3k))::Vector{Int}
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
