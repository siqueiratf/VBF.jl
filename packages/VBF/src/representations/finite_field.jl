"""
GF(2ⁿ) finite-field arithmetic.

Elements of `GF(2ⁿ)` are represented as `n`-bit non-negative integers
where bit `i` is the coefficient of `xⁱ`. Multiplication is performed
mod an irreducible polynomial of degree `n`; this module ships a
small lookup table of *primitive* irreducibles for `n ∈ 2:16` (each
chosen so the polynomial generates the multiplicative group of
`GF(2ⁿ)`) and accepts an explicit modulus as an optional argument.

The bit-pattern convention for the modulus is the polynomial itself
including its leading `xⁿ` bit, so e.g. `x⁴ + x + 1` is `0b10011 = 19`.

# Public surface
- [`PRIMITIVE_POLYNOMIALS`](@ref) — `Dict{Int, Int}` of canonical
  primitives for `n ∈ 2:16`. The n=4, 5, 8 choices match the
  conventions already used in `data-raw/apn_catalog/n{4,5}_apn.toml`
  and FIPS 197 / AES (n=8 uses Rijndael's `x⁸ + x⁴ + x³ + x + 1`).
- [`primitive_polynomial`](@ref) — fetch the default modulus for `n`.
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
    PRIMITIVE_POLYNOMIALS :: Dict{Int, Int}

Canonical primitive irreducible polynomial for `GF(2ⁿ)` at each
`n ∈ 2:16`. The value is the integer representation of the polynomial
including its leading `xⁿ` bit.

These match standard references (Lidl-Niederreiter, FIPS 197 for
n=8) and the moduli already used by the catalog's hand-computed LUTs
(`x⁴+x+1` for `n=4`, `x⁵+x²+1` for `n=5`).
"""
const PRIMITIVE_POLYNOMIALS = Dict{Int,Int}(
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

Canonical modulus for `GF(2ⁿ)`. Throws `ArgumentError` for `n` outside
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
