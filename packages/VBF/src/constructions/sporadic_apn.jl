"""
Sporadic / named APN instances — specific functions of historical or structural
importance that are not (presented as) members of an infinite family.
"""

# Browning–Dillon–McQuistan–Wolfe (2010), the lookup table as printed (read
# row-major, f(8·r + c) = entry[r][c]), over GF(2⁶) with MAGMA's default
# primitive element (minimal polynomial x⁶+x⁴+x³+x+1).
const _DILLON_N6_PERMUTATION = Int[
    0, 54, 48, 13, 15, 18, 53, 35,
    25, 63, 45, 52,  3, 20, 41, 33,
    59, 36,  2, 34, 10,  8, 57, 37,
    60, 19, 42, 14, 50, 26, 58, 24,
    39, 27, 21, 17, 16, 29,  1, 62,
    47, 40, 51, 56,  7, 43, 44, 38,
    31, 11,  4, 28, 61, 46,  5, 49,
     9,  6, 23, 32, 30, 12, 55, 22,
]

"""
    dillon_apn_permutation() -> SBox{6}

The Browning–Dillon–McQuistan–Wolfe (2010) APN permutation on `GF(2⁶)` — the
**only known APN permutation in even dimension** (the "big APN problem": whether
even-dimension APN permutations exist for `n ≠ 6` is open). It has algebraic
degree 4 and is CCZ-equivalent to a quadratic APN function.
"""
dillon_apn_permutation() = SBox{6}(copy(_DILLON_N6_PERMUTATION))
