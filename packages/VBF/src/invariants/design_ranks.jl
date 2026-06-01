"""
Design 2-ranks of APN functions — the Γ-rank and Δ-rank ([Edel and Pott, 2009](@cite EdelPott2009)).

For an APN function `F : F₂ⁿ → F₂ⁿ`, two CCZ-invariant integers come from the
`F₂`-rank of the incidence matrices of designs developed from its graph:

  * the **graph** `G_F = {(x, F(x)) : x ∈ F₂ⁿ} ⊆ F₂ⁿ × F₂ⁿ`, and
  * the **difference support** `D_F = {(a, b) : a ≠ 0, DDT_F[a,b] = 2}` (from
    `G_F · G_F = 2ⁿ·(0,0) + 2·D_F`, Edel–Pott Lemma 1).

The development `dev(S)` of a set `S ⊆ F₂^{2n}` takes the translates `S + v` as
blocks; its incidence matrix over `F₂^{2n}` is `B[p, q] = [p ⊕ q ∈ S]`. The
**Γ-rank** is `rank_{F₂} B` for `S = G_F`, the **Δ-rank** for `S = D_F`. Both are
invariant under CCZ-equivalence, and `Δ-rank ≤ 2^{n+1}`. They distinguish
CCZ-classes that share differential and Walsh spectra — e.g. Taniguchi's two new
`F₂⁸` families have equal ortho-derivative fingerprints but Γ-ranks 13700 vs
13798.

The matrix is `2^{2n} × 2^{2n}`, so the rank is tractable for `n ≤ 6` (instant to
seconds), heavy for `n = 7` (minutes), and impractical for `n = 8` (≈512 MB) —
the literature computes the latter with Magma.
"""

# Bit-packed F₂ Gaussian elimination of wide rows → rank (rows mutated).
function _f2_rank_wide!(rows::Vector{Vector{UInt64}}, ncols::Int)
    nwords = cld(ncols, 64)
    nrows = length(rows)
    r = 1
    rk = 0
    @inbounds for col = 0:(ncols-1)
        w = (col >> 6) + 1
        b = col & 63
        sel = 0
        for i = r:nrows
            if (rows[i][w] >> b) & 1 == 1
                sel = i
                break
            end
        end
        sel == 0 && continue
        rows[r], rows[sel] = rows[sel], rows[r]
        for i = (r+1):nrows
            if (rows[i][w] >> b) & 1 == 1
                for k = 1:nwords
                    rows[i][k] ⊻= rows[r][k]
                end
            end
        end
        r += 1
        rk += 1
        r > nrows && break
    end
    rk
end

# F₂-rank of the incidence matrix `B[p,q] = [p ⊕ q ∈ points]` on F₂^m.
function _design_2rank(points::Vector{Int}, m::Int)
    M = 1 << m
    nwords = cld(M, 64)
    rows = [zeros(UInt64, nwords) for _ = 1:M]
    @inbounds for p = 0:(M-1), s in points
        q = p ⊻ s
        rows[p+1][(q>>6)+1] |= (UInt64(1) << (q & 63))
    end
    _f2_rank_wide!(rows, M)
end

_design_rank_guard(N) =
    N ≤ 7 || throw(
        ArgumentError(
            "design ranks need a 2^$(2N) × 2^$(2N) matrix; n ≤ 7 supported " *
            "(n = 8 needs ≈512 MB and hours — compute it with Magma)",
        ),
    )

"""
    gamma_rank(F::SBox{N}) -> Int

The Γ-rank of APN `F`: the `F₂`-rank of the incidence matrix of `dev(G_F)` (the
development of the graph), a CCZ-invariant. Supports `n ≤ 7`.

# Examples
```jldoctest
julia> using VBF

julia> gamma_rank(gold_apn(5, 1))
330
```
"""
function gamma_rank(F::SBox{N}) where {N}
    _design_rank_guard(N)
    pts = [Int(x) | (Int(F.lut[x+1]) << N) for x = 0:((1<<N)-1)]
    _design_2rank(pts, 2N)
end

"""
    delta_rank(F::SBox{N}) -> Int

The Δ-rank of APN `F`: the `F₂`-rank of the incidence matrix of `dev(D_F)` with
`D_F = {(a,b) : a ≠ 0, DDT[a,b] = 2}`, a CCZ-invariant with `Δ-rank ≤ 2^{n+1}`.
Supports `n ≤ 7`.

# Examples
```jldoctest
julia> using VBF

julia> delta_rank(gold_apn(5, 1))  # bounded by 2^(5+1) = 64
42
```
"""
function delta_rank(F::SBox{N}) where {N}
    _design_rank_guard(N)
    D = ddt(F)
    pts = Int[]
    @inbounds for a = 1:((1<<N)-1), b = 0:((1<<N)-1)
        D[a+1, b+1] == 2 && push!(pts, a | (b << N))
    end
    _design_2rank(pts, 2N)
end
