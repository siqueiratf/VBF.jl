# Implements core helpers for isotopic shift construction.
# Paper: Budaghyan et al. (2020), "Constructing APN Functions Through Isotopic Shifts",
#        IEEE Trans. Inf. Theory 66(8), pp. 5299–5309. DOI: 10.1109/TIT.2020.2974471
# Section: I (Definition I.1), VI (Equation 6)
#
# Pseudocode:
#   1. F_L(x) = F(x ⊕ L(x)) ⊕ F(x) ⊕ F(L(x))           (Def. I.1)
#   2. G_{i,L}(x) = x^{2^i}·L(x) + x·L(x)^{2^i}          (Eq. 6, same as 1 for Gold)
#   3. ζ = a primitive element of GF(2^n) — every ζ^k exponent quoted from the
#      paper is meaningful only relative to (modulus, ζ), so ζ is *searched*, not
#      assumed to be 2: for n = 8, primitive_polynomial(8) = 283 (the AES
#      polynomial) and 2 has multiplicative order 51, not 255.
# VBF API used: gf_mul, gf_pow, gf_monomial_lut, terms_to_lut, kernel_f2,
#               is_permutation, zero_linear_map, identity_linear_map,
#               primitive_polynomial, SBox, differential_uniformity,
#               print_banner / print_section / print_check / print_kv

using VBF

# ── Isotopic shift ────────────────────────────────────────────────────────────

"""
    isotopic_shift_lut(F_lut, L_lut) -> Vector{Int}

LUT of the isotopic shift F_L: F_L(x) = F(x⊕L(x)) ⊕ F(x) ⊕ F(L(x)).
"""
function isotopic_shift_lut(
    F_lut::AbstractVector{<:Integer},
    L_lut::AbstractVector{<:Integer},
)
    N = length(F_lut)
    out = Vector{Int}(undef, N)
    for x in 0:N-1
        lx = Int(L_lut[x+1])
        out[x+1] = Int(F_lut[(x ⊻ lx)+1] ⊻ F_lut[x+1] ⊻ F_lut[lx+1])
    end
    out
end

# ── Field pinning (ζ) ─────────────────────────────────────────────────────────

"""
    multiplicative_order(g, n; modulus) -> Int

Multiplicative order of `g` in GF(2^n)*, or `-1` if `g = 0`.
"""
function multiplicative_order(
    g::Integer,
    n::Int;
    modulus::Int = primitive_polynomial(n),
)
    g == 0 && return -1
    z = 1
    for k in 1:(1<<n)-1
        z = gf_mul(z, g, n; modulus = modulus)
        z == 1 && return k
    end
    -1
end

"""
    primitive_element(n; modulus) -> Int

Smallest primitive element ζ of GF(2^n) under `modulus`, i.e. the smallest `g`
with multiplicative order 2^n − 1.

The paper writes every coefficient as a power ζ^k, so a *concrete* ζ must be
pinned before any of those exponents mean anything.  `2` is primitive for the
`primitive_polynomial(n)` of most n (including n = 9, the paper's headline
field) but **not** for n = 8, where the AES modulus 283 gives 2 order 51.
"""
function primitive_element(n::Int; modulus::Int = primitive_polynomial(n))
    target = (1 << n) - 1
    for g in 2:target
        multiplicative_order(g, n; modulus = modulus) == target && return g
    end
    error("primitive_element: none found in GF(2^$n) with modulus $modulus")
end

# ── Linear map LUTs ───────────────────────────────────────────────────────────

"""
    linear_map_lut(L::F2LinearMap) -> Vector{Int}

Bridge from a VBF `F2LinearMap` to the plain LUT form used by
[`isotopic_shift_lut`](@ref).
"""
linear_map_lut(L::F2LinearMap{N}) where {N} = [Int(L(x)) for x in 0:(1<<N)-1]

"""
    zero_map_lut(n) -> Vector{Int}

LUT for the zero linear map L(x) = 0 (`VBF.zero_linear_map`).
"""
zero_map_lut(n::Int) = linear_map_lut(zero_linear_map(n))

"""
    identity_map_lut(n) -> Vector{Int}

LUT for the identity linear map L(x) = x (`VBF.identity_linear_map`).
"""
identity_map_lut(n::Int) = linear_map_lut(identity_linear_map(n))

# Linearised polynomials L(x) = Σ bⱼ·x^{2^j} are built directly with
# `VBF.terms_to_lut([(b_j, 2^j), …], n, modulus)` at the call sites — no
# paper-local monomial/trinomial LUT builders (they duplicated core GF arithmetic).

# ── Kernel / valence helpers (thin over VBF.kernel_f2 / VBF.is_permutation) ───

"""
    linear_map_rows(L_lut) -> Vector{UInt64}

Row-bitmask form of the F₂-matrix of the linear map `L_lut`, as consumed by
`VBF.kernel_f2`: row `i` carries bit `k` iff bit `i` of `L(2^k)` is set.
"""
function linear_map_rows(L_lut::AbstractVector{<:Integer})
    n = trailing_zeros(length(L_lut))
    rows = zeros(UInt64, n)
    for k in 0:n-1
        v = Int(L_lut[(1<<k)+1])
        for i in 0:n-1
            ((v >> i) & 1) == 1 && (rows[i+1] |= UInt64(1) << k)
        end
    end
    rows
end

"""
    kernel_dimension(L_lut) -> Int

dim_F₂ ker(L), computed by `VBF.kernel_f2`.
"""
function kernel_dimension(L_lut::AbstractVector{<:Integer})
    n = trailing_zeros(length(L_lut))
    length(kernel_f2(linear_map_rows(L_lut); nbits = n))
end

"""
    kernel_size(L_lut) -> Int

|ker(L)| = 2^dim ker(L).
"""
kernel_size(L_lut::AbstractVector{<:Integer}) = 1 << kernel_dimension(L_lut)

"""
    is_2to1(L_lut) -> Bool

True when `L` is 2-to-1, i.e. dim ker(L) = 1 (two preimages per image point).
"""
is_2to1(L_lut::AbstractVector{<:Integer}) = kernel_dimension(L_lut) == 1

"""
    is_permutation_map(L_lut) -> Bool

True when `L` is a permutation, via `VBF.is_permutation`.
"""
function is_permutation_map(L_lut::AbstractVector{<:Integer})
    n = trailing_zeros(length(L_lut))
    is_permutation(SBox{n}(collect(Int, L_lut)))
end

"""
    injective_on_image(L_lut) -> Bool

True when `L` restricted to its image 𝒱(L) = L(GF(2ⁿ)) is injective — the second
half of Theorem V.1(i)/(ii).
"""
function injective_on_image(L_lut::AbstractVector{<:Integer})
    img = unique(L_lut)
    length(unique(L_lut[Int(v)+1] for v in img)) == length(img)
end

"""
    is_zero_map(lut) -> Bool
"""
is_zero_map(lut::AbstractVector{<:Integer}) = all(==(0), lut)

# ── GF arithmetic helpers ─────────────────────────────────────────────────────

"""
    find_c_for_d(d, n; modulus) -> Int

Return any c ∈ GF(2^n) with c² ⊕ c = d (Artin–Schreier equation).  Solvable iff
Tr(d) = 0; throws otherwise.

NOTE (library reuse): a general `artin_schreier_solve` belongs in
`packages/VBF/src/` (see README, "Promote-to-core candidate").  Kept paper-local
here deliberately; this is an O(2ⁿ) scan.
"""
function find_c_for_d(d::Integer, n::Int; modulus::Int = primitive_polynomial(n))
    gf_trace(d, n; modulus = modulus) == 0 || error(
        "find_c_for_d: c²+c=d is unsolvable for d=$d in GF(2^$n) (Tr(d)=1)",
    )
    for c in 0:(1<<n)-1
        gf_pow(c, 2, n; modulus = modulus) ⊻ c == d && return c
    end
    error("find_c_for_d: no solution for d=$d in GF(2^$n)")
end
