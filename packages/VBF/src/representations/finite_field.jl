"""
GF(2ⁿ) finite-field arithmetic.

Elements of `GF(2ⁿ)` are represented as `n`-bit non-negative integers
where bit `i` is the coefficient of `xⁱ`. Multiplication is performed
mod an irreducible polynomial of degree `n`; this module ships a
small lookup table of irreducible moduli for `n ∈ 2:16` and accepts an explicit modulus as an optional argument.

The bit-pattern convention for the modulus is the polynomial itself
including its leading `xⁿ` bit, so e.g. `x⁴ + x + 1` is `0b10011 = 19`.

# Public surface
- [`IRREDUCIBLE_POLYNOMIALS`](@ref) — `Dict{Int, Int}` of canonical
  moduli for `n ∈ 2:16`. The n=4, 5, 8 choices match the
  conventions already used in `src/entries/apn_catalog/n{4,5}_apn.toml`
  and FIPS 197 / AES (n=8 uses Rijndael's `x⁸ + x⁴ + x³ + x + 1`).
- [`irreducible_polynomial`](@ref) — fetch the default modulus for `n`.
- [`gf_primitive_element`](@ref) — a verified multiplicative generator.
  The historical `primitive_polynomial` name refers to a modulus, not a
  guarantee that element `2` generates its multiplicative group.
- [`gf_mul`](@ref) — multiplication in `GF(2ⁿ)`.
- [`gf_pow`](@ref) — square-and-multiply exponentiation.
- [`gf_inv`](@ref) — multiplicative inverse via Fermat (`a^(2ⁿ - 2)`).
- [`gf_monomial_lut`](@ref) — full `2ⁿ`-entry LUT for `x ↦ xᵈ`.

# Examples
```jldoctest
julia> using VBF

julia> gf_mul(2, 3, 4)              # 2 · 3 in GF(2⁴) with x⁴ + x + 1
6

julia> gf_pow(2, 3, 4)             # x³ where x is the field generator
8

julia> gf_monomial_lut(4, 3)       # the n=4 Gold x³ APN LUT
16-element Vector{Int64}:
  0
  1
  8
 15
 12
 10
  1
  1
 10
 15
 15
 12
  8
 10
  8
 12
```
"""

# Primitive-polynomial lookup

"""
    IRREDUCIBLE_POLYNOMIALS :: Dict{Int, Int}

Canonical irreducible polynomial for `GF(2ⁿ)` at each
`n ∈ 2:16`. The value is the integer representation of the polynomial
including its leading `xⁿ` bit.

These match standard references (Lidl-Niederreiter, FIPS 197 for
n=8) and the moduli already used by the catalog's hand-computed LUTs
(`x⁴+x+1` for `n=4`, `x⁵+x²+1` for `n=5`).
"""
const IRREDUCIBLE_POLYNOMIALS = Dict{Int,Int}(
    2 => 0b111,                       # x² + x + 1
    3 => 0b1011,                      # x³ + x + 1
    4 => 0b10011,                     # x⁴ + x + 1
    5 => 0b100101,                    # x⁵ + x² + 1
    6 => 0b1000011,                   # x⁶ + x + 1
    7 => 0b10000011,                  # x⁷ + x + 1
    8 => 0b100011011,                 # x⁸ + x⁴ + x³ + x + 1   (AES)
    9 => 0b1000010001,                # x⁹ + x⁴ + 1
    10 => 0b10000001001,               # x¹⁰ + x³ + 1
    11 => 0b100000000101,              # x¹¹ + x² + 1
    12 => 0b1000001010011,             # x¹² + x⁶ + x⁴ + x + 1
    13 => 0b10000000011011,            # x¹³ + x⁴ + x³ + x + 1
    14 => 0b100000000101011,           # x¹⁴ + x⁵ + x³ + x + 1
    15 => 0b1000000000000011,          # x¹⁵ + x + 1
    16 => 0b10000000000101101,         # x¹⁶ + x⁵ + x³ + x² + 1
)

"""
    PRIMITIVE_POLYNOMIALS

Historical alias of [`IRREDUCIBLE_POLYNOMIALS`](@ref). The n=8 AES modulus is
irreducible but not primitive: element `2` has order 51, not 255. Existing field
bases are preserved. Use [`gf_primitive_element`](@ref) for exponent indexing.
"""
const PRIMITIVE_POLYNOMIALS = IRREDUCIBLE_POLYNOMIALS

"""
    CONWAY_POLYNOMIALS :: Dict{Int, Int}

Conway polynomials for `GF(2ⁿ)`, `n ∈ 2:10`. These are the irreducible
polynomials that SageMath uses by default for `GF(2^n)`, so any
polynomial-form APN list authored against Sage (e.g., the Xanadu
`apn-ccz-graph-framework` corpus) evaluates correctly under this
modulus. For `n ∈ {2, 3, 4, 5, 7, 9}` the Conway polynomial coincides
with the entry in [`PRIMITIVE_POLYNOMIALS`](@ref); the two tables
differ for `n ∈ {6, 8, 10}`.
"""
const CONWAY_POLYNOMIALS = Dict{Int,Int}(
    2 => 0b111,                       # x² + x + 1
    3 => 0b1011,                      # x³ + x + 1
    4 => 0b10011,                     # x⁴ + x + 1
    5 => 0b100101,                    # x⁵ + x² + 1
    6 => 0b1011011,                   # x⁶ + x⁴ + x³ + x + 1
    7 => 0b10000011,                  # x⁷ + x + 1
    8 => 0b100011101,                 # x⁸ + x⁴ + x³ + x² + 1
    9 => 0b1000010001,                # x⁹ + x⁴ + 1
    10 => 0b10001101111,               # x¹⁰ + x⁶ + x⁵ + x³ + x² + x + 1
)

"""
    conway_polynomial(n::Integer) -> Int

Conway polynomial for `GF(2ⁿ)`. See [`CONWAY_POLYNOMIALS`](@ref).
"""
function conway_polynomial(n::Integer)
    haskey(CONWAY_POLYNOMIALS, Int(n)) ||
        throw(ArgumentError("conway_polynomial: no Conway polynomial for n=$n"))
    CONWAY_POLYNOMIALS[Int(n)]
end

"""
    primitive_polynomial(n::Integer) -> Int

Historical name for the canonical **irreducible** modulus for `GF(2ⁿ)`.
It does not guarantee that element `2` is primitive; at n=8 it is not.
Use [`gf_primitive_element`](@ref) when a multiplicative generator is needed.
Throws `ArgumentError` for `n` outside
the table; pass an explicit modulus to [`gf_mul`](@ref) for the
unsupported case.
"""
function primitive_polynomial(n::Integer)
    haskey(PRIMITIVE_POLYNOMIALS, Int(n)) || throw(
        ArgumentError(
            "primitive_polynomial: no canonical modulus for n=$n; pass one explicitly to gf_mul",
        ),
    )
    PRIMITIVE_POLYNOMIALS[Int(n)]
end

"""
    irreducible_polynomial(n::Integer) -> Int

Canonical field modulus, preserving the historical polynomial basis, including
AES at n=8. Equivalent to [`primitive_polynomial`](@ref), whose name predates
the distinction between a field modulus and a multiplicative generator.
"""
irreducible_polynomial(n::Integer) = primitive_polynomial(n)

# Multiplication, exponentiation, inversion

"""
    gf_mul(a::Integer, b::Integer, n::Integer; modulus = primitive_polynomial(n)) -> Int

Multiply `a` and `b` in `GF(2ⁿ)` modulo `modulus`. Inputs and outputs
fit in the low `n` bits. Time is `O(n)`.
"""
function gf_mul(
    a::Integer,
    b::Integer,
    n::Integer;
    modulus::Integer = primitive_polynomial(n),
)
    n ≥ 1 || throw(ArgumentError("gf_mul: n must be ≥ 1, got $n"))
    aI = Int(a)
    bI = Int(b)
    p = 0
    @inbounds for i = 0:(n-1)
        ((bI >> i) & 1) == 1 && (p ⊻= aI << i)
    end
    # reduce: as long as p has bits at position ≥ n, XOR shifted modulus
    while p ≥ (1 << n)
        hi = n
        while ((p >> hi) & 1) == 0
            hi += 1
        end
        p ⊻= Int(modulus) << (hi - n)
    end
    p
end

"""
    gf_pow(x::Integer, k::Integer, n::Integer; modulus = primitive_polynomial(n)) -> Int

`xᵏ` in `GF(2ⁿ)`. Square-and-multiply; `O(n · log k)`. By convention
`gf_pow(0, 0, n) = 1`.
"""
function gf_pow(
    x::Integer,
    k::Integer,
    n::Integer;
    modulus::Integer = primitive_polynomial(n),
)
    k ≥ 0 || throw(
        ArgumentError(
            "gf_pow: k must be ≥ 0, got $k (use gf_inv for negative exponents)",
        ),
    )
    if k == 0
        return 1
    end
    base = Int(x)
    if base == 0
        return 0
    end
    acc = 1
    e = Int(k)
    while e > 0
        (e & 1) == 1 && (acc = gf_mul(acc, base, n; modulus = modulus))
        e >>= 1
        e > 0 && (base = gf_mul(base, base, n; modulus = modulus))
    end
    acc
end

"""
    gf_inv(a::Integer, n::Integer; modulus = primitive_polynomial(n)) -> Int

Multiplicative inverse `a⁻¹` in `GF(2ⁿ)`, via Fermat's little theorem
(`a^(2ⁿ - 2)`). Throws `ArgumentError` if `a == 0`.
"""
function gf_inv(
    a::Integer,
    n::Integer;
    modulus::Integer = primitive_polynomial(n),
)
    Int(a) == 0 && throw(ArgumentError("gf_inv: 0 is not invertible"))
    gf_pow(a, (1 << n) - 2, n; modulus = modulus)
end

"""
    gf_inv_zero_safe(a::Integer, n::Integer; modulus = primitive_polynomial(n)) -> Int

Multiplicative inverse with the cryptographic convention `0⁻¹ = 0`.
Equivalent to `a == 0 ? 0 : gf_inv(a, n; modulus)`.
"""
function gf_inv_zero_safe(
    a::Integer,
    n::Integer;
    modulus::Integer = primitive_polynomial(n),
)
    Int(a) == 0 && return 0
    gf_pow(a, (1 << n) - 2, n; modulus = modulus)
end

# Monomial lookup table

"""
    gf_monomial_lut(n::Integer, d::Integer; modulus = primitive_polynomial(n)) -> Vector{Int}

Length-`2ⁿ` lookup table of `x ↦ xᵈ` in `GF(2ⁿ)`, indexed by `x` in
`0:2ⁿ - 1`. Useful for instantiating monomial S-boxes from the Gold
([Gold, 1968](@cite Gold_196801)), Kasami, Welch, Niho, and Dobbertin families.

# Examples
```jldoctest
julia> using VBF

julia> lut = gf_monomial_lut(4, 3);  # Gold x³ over GF(2⁴)

julia> lut == [0, 1, 8, 15, 12, 10, 1, 1, 10, 15, 15, 12, 8, 10, 8, 12]
true
```
"""
function gf_monomial_lut(
    n::Integer,
    d::Integer;
    modulus::Integer = primitive_polynomial(n),
)
    n ≥ 1 || throw(ArgumentError("gf_monomial_lut: n must be ≥ 1, got $n"))
    d ≥ 0 ||
        throw(ArgumentError("gf_monomial_lut: exponent d must be ≥ 0, got $d"))
    len = 1 << n
    out = Vector{Int}(undef, len)
    @inbounds for x = 0:(len-1)
        out[x+1] = gf_pow(x, d, n; modulus = modulus)
    end
    out
end

# Traces and subfields

"""
    gf_trace(x::Integer, n::Integer; modulus = primitive_polynomial(n)) -> Int

Absolute trace `Tr_{GF(2ⁿ)/GF(2)}(x) = x ⊕ x² ⊕ x⁴ ⊕ … ⊕ x^{2ⁿ⁻¹}`, an
element of `GF(2)`, so the result is `0` or `1`. Computed by `n` repeated
squarings; `O(n²)`.

# Examples
```jldoctest
julia> using VBF

julia> gf_trace(0, 4)
0

julia> sum(gf_trace(x, 4) for x = 0:15)  # the trace is balanced on GF(2ⁿ)
8
```
"""
function gf_trace(x::Integer, n::Integer; modulus::Integer = primitive_polynomial(n))
    n ≥ 1 || throw(ArgumentError("gf_trace: n must be ≥ 1, got $n"))
    acc = 0
    t = Int(x)
    @inbounds for _ = 1:n
        acc ⊻= t
        t = gf_mul(t, t, n; modulus = modulus)
    end
    acc
end

"""
    gf_relative_trace(x::Integer, n::Integer, k::Integer; modulus = primitive_polynomial(n)) -> Int

Relative trace `Tr_{GF(2ⁿ)/GF(2ᵏ)}(x) = x ⊕ x^{2ᵏ} ⊕ x^{2^{2k}} ⊕ … ⊕
x^{2^{(n/k − 1)k}}`. Requires `k ∣ n`; the result lies in the subfield
`GF(2ᵏ) ⊆ GF(2ⁿ)` (see [`in_subfield`](@ref)).
"""
function gf_relative_trace(
    x::Integer,
    n::Integer,
    k::Integer;
    modulus::Integer = primitive_polynomial(n),
)
    (n ≥ 1 && k ≥ 1) ||
        throw(ArgumentError("gf_relative_trace: need n,k ≥ 1, got n=$n, k=$k"))
    n % k == 0 || throw(ArgumentError("gf_relative_trace: k=$k must divide n=$n"))
    steps = n ÷ k
    frobenius = 1 << k
    acc = 0
    t = Int(x)
    @inbounds for _ = 1:steps
        acc ⊻= t
        t = gf_pow(t, frobenius, n; modulus = modulus)
    end
    acc
end

"""
    in_subfield(x::Integer, k::Integer, n::Integer; modulus = primitive_polynomial(n)) -> Bool

Whether `x` lies in the subfield `GF(2ᵏ) ⊆ GF(2ⁿ)`, tested by the Frobenius
fixed-point condition `x^{2ᵏ} = x`. Requires `k ∣ n`.
"""
function in_subfield(
    x::Integer,
    k::Integer,
    n::Integer;
    modulus::Integer = primitive_polynomial(n),
)
    n % k == 0 || throw(ArgumentError("in_subfield: k=$k must divide n=$n"))
    gf_pow(Int(x), 1 << k, n; modulus = modulus) == Int(x)
end

"""
    subfield_elements(n::Integer, k::Integer; modulus = primitive_polynomial(n)) -> Vector{Int}

The `2ᵏ` elements of the subfield `GF(2ᵏ) ⊆ GF(2ⁿ)` (including `0`), in
ascending order. Requires `k ∣ n`. Selected by the Frobenius fixed-point test
of [`in_subfield`](@ref), so the result is independent of which primitive
element the modulus encodes.

# Examples
```jldoctest
julia> using VBF

julia> subfield_elements(4, 2)  # GF(2²) inside GF(2⁴), default modulus
4-element Vector{Int64}:
 0
 1
 6
 7
```
"""
function subfield_elements(
    n::Integer,
    k::Integer;
    modulus::Integer = primitive_polynomial(n),
)
    n % k == 0 || throw(ArgumentError("subfield_elements: k=$k must divide n=$n"))
    frobenius = 1 << k
    [x for x = 0:((1 << n) - 1) if gf_pow(x, frobenius, n; modulus = modulus) == x]
end

"""
    gf_is_dth_power(x::Integer, d::Integer, n::Integer; modulus = primitive_polynomial(n)) -> Bool

Whether `x` is a `d`-th power in `GF(2ⁿ)`, i.e. `x = yᵈ` for some `y`. By
convention `0` is a `d`-th power.

The `d`-th powers of the cyclic group `GF(2ⁿ)*` form the subgroup of index
`g = gcd(d, 2ⁿ − 1)`, so a nonzero `x` is a `d`-th power iff
`x^{(2ⁿ − 1)/g} = 1`. When `g = 1` the map `y ↦ yᵈ` is a bijection and every
element qualifies; this covers, e.g., cubes when `3 ∤ 2ⁿ − 1`.

# Examples
```jldoctest
julia> using VBF

julia> gf_is_dth_power(0, 3, 6)
true

julia> count(x -> gf_is_dth_power(x, 3, 6), 1:62)  # cubes in GF(2⁶)*: (2⁶−1)/3 = 21
21
```
"""
function gf_is_dth_power(
    x::Integer,
    d::Integer,
    n::Integer;
    modulus::Integer = primitive_polynomial(n),
)
    Int(x) == 0 && return true
    order = (1 << n) - 1
    g = gcd(Int(d), order)
    gf_pow(Int(x), order ÷ g, n; modulus = modulus) == 1
end

# Distinct prime divisors; these field-sized integers need no external package.
function _gf_prime_factors(n::Int)
    out=Int[];d=2
    while d<=n÷d
        if n%d==0
            push!(out,d)
            while n%d==0;n÷=d;end
        end
        d+=1
    end
    n>1 && push!(out,n)
    out
end

function _gf_poly_gcd(a::Int,b::Int)
    while b!=0
        while a!=0 && ndigits(a;base=2)>=ndigits(b;base=2)
            a ⊻= b << (ndigits(a;base=2)-ndigits(b;base=2))
        end
        a,b=b,a
    end
    a
end

function _gf_generator_domain(n::Integer,modulus::Integer)
    nn=Int(n);p=Int(modulus)
    1<=nn<=(8sizeof(Int)-2)÷2 || throw(ArgumentError("field dimension exceeds safe Int multiplication range"))
    (1<<nn)<=p<(1<<(nn+1)) || throw(ArgumentError("modulus must have degree n"))
    if nn==1
        p==3 || throw(ArgumentError("modulus is reducible"))
    else
        gf_pow(2,1<<nn,nn;modulus=p)==2 || throw(ArgumentError("modulus is reducible"))
        for q in _gf_prime_factors(nn)
            _gf_poly_gcd(gf_pow(2,1<<(nn÷q),nn;modulus=p) ⊻ 2,p)==1 ||
                throw(ArgumentError("modulus is reducible"))
        end
    end
    nn,p
end

function _gf_order(x::Int,n::Int,p::Int,factors)
    order=(1<<n)-1
    for q in factors
        while order%q==0 && gf_pow(x,order÷q,n;modulus=p)==1
            order÷=q
        end
    end
    order
end

"""
    gf_multiplicative_order(x, n; modulus=primitive_polynomial(n)) -> Int

Exact multiplicative order of a nonzero field element. Checks that the modulus
is irreducible of degree n; rejects zero and elements outside the n-bit field.
Supports dimensions fitting the existing Int multiplication implementation.
"""
function gf_multiplicative_order(x::Integer,n::Integer;modulus::Integer=primitive_polynomial(n))
    nn,p=_gf_generator_domain(n,modulus)
    0<x<(1<<nn) || throw(ArgumentError("multiplicative order requires a nonzero n-bit element"))
    _gf_order(Int(x),nn,p,_gf_prime_factors((1<<nn)-1))
end

"""
    gf_primitive_element(n; modulus=primitive_polynomial(n)) -> Int

Smallest nonzero element generating GF(2ⁿ)* in the specified irreducible field
basis. Primitivity is checked using every prime divisor of 2ⁿ-1. In the default
AES basis at n=8 the answer is 3; in the Conway basis it is 2. Never change a
stored polynomial basis merely to make element 2 primitive.
"""
function gf_primitive_element(n::Integer;modulus::Integer=primitive_polynomial(n))
    nn,p=_gf_generator_domain(n,modulus);order=(1<<nn)-1
    factors=_gf_prime_factors(order)
    for x in 1:order
        all(q->gf_pow(x,order÷q,nn;modulus=p)!=1,factors) && return x
    end
    error("no generator in the validated field")
end
