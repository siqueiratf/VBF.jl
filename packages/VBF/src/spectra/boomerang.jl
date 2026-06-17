"""
Boomerang cryptanalysis primitives.

For a permutation `F : F₂ᴺ → F₂ᴺ`, the **Boomerang Connectivity Table**
(BCT) of [Cid, Huang, Peyrin, Sasaki and Song (2018)](@cite Cid_201804) records the
joint probability of two complementary differentials in a boomerang
distinguisher:

``BCT[a, b] = \\#\\{ x : F^{-1}(F(x) ⊕ b) ⊕ F^{-1}(F(x ⊕ a) ⊕ b) = a \\}``.

The Feistel variant (**FBCT**) does the same accounting for a single
Feistel branch and does *not* require an inverse:

``FBCT[a, b] = \\#\\{ x : F(x) ⊕ F(x ⊕ a) ⊕ F(x ⊕ b) ⊕ F(x ⊕ a ⊕ b) = 0 \\}``.

# Public surface
- [`bct`](@ref) — table; `s` must be a permutation.
- [`boomerang_spectrum`](@ref), [`boomerang_uniformity`](@ref) — derived.
- [`fbct`](@ref), [`fbct_spectrum`](@ref), [`fbct_uniformity`](@ref) — Feistel variant.
"""

# === BCT ====================================================================

"""
    bct(s::SBox{N, T}) -> Matrix{Int}

Boomerang Connectivity Table of `s`, sized `2^N × 2^N`. Throws
`ArgumentError` if `s` is not a permutation.

Invariants:
- `bct(s)[a + 1, 1] = 2^N` for every `a`  (column `b = 0`)
- `bct(s)[1, b + 1] = 2^N` for every `b`  (row `a = 0`)
- `bct(s)[a + 1, b + 1] ≥ ddt(s)[a + 1, b + 1]` (Cid et al. Lemma 1).
- Every entry is even for `N ≥ 2`.
"""
function bct(s::SBox{N,T}) where {N,T}
    n = 1 << N
    sinv = inv(s)               # validates permutation
    lut = s.lut
    inv_lut = sinv.lut
    B = zeros(Int, n, n)
    @inbounds for a = 0:(n-1), b = 0:(n-1)
        c = 0
        Tb = T(b)
        for x = 0:(n-1)
            Fx = lut[x+1]
            Fxa = lut[(x⊻a)+1]
            l = inv_lut[(Fx⊻Tb)+1]
            r = inv_lut[(Fxa⊻Tb)+1]
            (l ⊻ r) == T(a) && (c += 1)
        end
        B[a+1, b+1] = c
    end
    B
end

"""
    boomerang_spectrum(s::SBox) -> Spectrum

Histogram of `bct(s)` entries excluding the trivial row (`a = 0`) and
trivial column (`b = 0`); peak = [`boomerang_uniformity`](@ref).
"""
function boomerang_spectrum(s::SBox)
    B = bct(s)
    n = size(B, 1)
    sp = Spectrum()
    @inbounds for a = 2:n, b = 2:n
        add!(sp, B[a, b])
    end
    sp
end

"""
    boomerang_uniformity(s::SBox) -> Int

Largest `bct(s)` entry outside row `a = 0` and column `b = 0`.

# Examples
```jldoctest
julia> using VBF

julia> boomerang_uniformity(load_literature_sbox("AES"))
6
```
"""
function boomerang_uniformity(s::SBox)
    B = bct(s)
    n = size(B, 1)
    u = 0
    @inbounds for a = 2:n, b = 2:n
        B[a, b] > u && (u = B[a, b])
    end
    u
end

# === FBCT ===================================================================

"""
    fbct(s::SBox{N, T}) -> Matrix{Int}

Feistel Boomerang Connectivity Table.
`fbct(s)[a + 1, b + 1] = #{ x : F(x) ⊕ F(x ⊕ a) ⊕ F(x ⊕ b) ⊕ F(x ⊕ a ⊕ b) = 0 }`.

Does not require `s` to be a permutation.

Invariants:
- `fbct(s)[a + 1, 1] = 2^N` for every `a` (column `b = 0`, second-derivative trivially zero).
- `fbct(s)[1, b + 1] = 2^N` for every `b` (row `a = 0`).
- `fbct(s)[a + 1, a + 1] = 2^N` (diagonal: `b = a` gives `F ⊕ F ⊕ F ⊕ F = 0`).
- Entries are even for `N ≥ 2`.
"""
function fbct(s::SBox{N,T}) where {N,T}
    n = 1 << N
    lut = s.lut
    F = zeros(Int, n, n)
    @inbounds for a = 0:(n-1), b = 0:(n-1)
        c = 0
        for x = 0:(n-1)
            v = lut[x+1] ⊻ lut[(x⊻a)+1] ⊻ lut[(x⊻b)+1] ⊻ lut[(x⊻a⊻b)+1]
            v == zero(T) && (c += 1)
        end
        F[a+1, b+1] = c
    end
    F
end

"""
    fbct_spectrum(s::SBox) -> Spectrum

Histogram of `fbct(s)` entries excluding row `a = 0`, column `b = 0`, and the
trivial diagonal entries where `b = a`.
"""
function fbct_spectrum(s::SBox)
    F = fbct(s)
    n = size(F, 1)
    sp = Spectrum()
    @inbounds for a = 2:n, b = 2:n
        a == b && continue
        add!(sp, F[a, b])
    end
    sp
end

"""
    fbct_uniformity(s::SBox) -> Int

Largest `fbct(s)` entry outside row `a = 0`, column `b = 0`, and the trivial
diagonal `b = a`.
"""
function fbct_uniformity(s::SBox)
    F = fbct(s)
    n = size(F, 1)
    u = 0
    @inbounds for a = 2:n, b = 2:n
        a == b && continue
        F[a, b] > u && (u = F[a, b])
    end
    u
end
