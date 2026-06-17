"""
Sporadic / named APN instances — specific functions of historical or structural
importance that are not (presented as) members of an infinite family.
"""

# Browning-Dillon-McQuistan-Wolfe (2010), row-major: f(8r + c) = entry[r][c].
const _DILLON_N6_PERMUTATION = Int[
    0,
    54,
    48,
    13,
    15,
    18,
    53,
    35,
    25,
    63,
    45,
    52,
    3,
    20,
    41,
    33,
    59,
    36,
    2,
    34,
    10,
    8,
    57,
    37,
    60,
    19,
    42,
    14,
    50,
    26,
    58,
    24,
    39,
    27,
    21,
    17,
    16,
    29,
    1,
    62,
    47,
    40,
    51,
    56,
    7,
    43,
    44,
    38,
    31,
    11,
    4,
    28,
    61,
    46,
    5,
    49,
    9,
    6,
    23,
    32,
    30,
    12,
    55,
    22,
]

"""
    dillon_apn_permutation() -> SBox{6}

The [Browning–Dillon–McQuistan–Wolfe (2010)](@cite Browning_201000)
APN permutation on `GF(2⁶)` — the
**only known APN permutation in even dimension** (the "big APN problem": whether
even-dimension APN permutations exist for `n ≠ 6` is open). It has algebraic
degree 4 and is CCZ-equivalent to a quadratic APN function.

# Examples
```jldoctest
julia> using VBF

julia> F = dillon_apn_permutation();

julia> (is_permutation(F), differential_uniformity(F), algebraic_degree(F))
(true, 2, 4)
```
"""
dillon_apn_permutation() = SBox{6}(copy(_DILLON_N6_PERMUTATION))

"""
    kim_apn() -> SBox{6}

The **Kim function** `κ(x) = x³ + x¹⁰ + u·x²⁴` over `GF(2⁶)`
([Browning, Dillon, McQuistan and Wolfe, 2010](@cite Browning_201000)),
with `u` the generator under the Conway polynomial `x⁶+x⁴+x³+x+1` (MAGMA's
default primitive element). It is a **quadratic** APN function that is
CCZ-equivalent to [`dillon_apn_permutation`](@ref): the quadratic source from
which the only known even-dimension APN permutation was obtained. The name and
the butterfly decomposition that explains this CCZ-equivalence are due to
[Perrin, Udovenko and Biryukov (2016)](@cite Perrin_201608).
(APN-ness depends on this specific field: under a different `GF(2⁶)`
representation the same coefficients are not APN.)

# Examples
```jldoctest
julia> using VBF

julia> K = kim_apn();

julia> (is_permutation(K), differential_uniformity(K), algebraic_degree(K))
(false, 2, 2)
```
"""
function kim_apn()
    mod = conway_polynomial(6)                     # x⁶+x⁴+x³+x+1
    SBox{6}([
        gf_pow(x, 3, 6; modulus = mod) ⊻ gf_pow(x, 10, 6; modulus = mod) ⊻
        gf_mul(2, gf_pow(x, 24, 6; modulus = mod), 6; modulus = mod) for
        x = 0:63
    ])
end
