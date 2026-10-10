"""
Edel-Pott / Calderini graph-code generator matrices.

For a function `F : F₂ⁿ → F₂ⁿ`, the **CCZ-code**, **EA-code**,
**AE-code** and **AE-permutation-code** are binary linear codes whose
permutation-equivalence captures CCZ-, EA- and affine-equivalence of the
underlying functions (Edel-Pott, "On the equivalence of nonlinear
functions", 2009, Theorems 9-11; Calderini, "On the EA-classes of known
APN functions in small dimensions", 2020, Theorem 6). This file builds
their generator matrices (`ccz_matrix` / `ea_matrix` / `ae_matrix` /
`ae_perm_matrix`) plus the `code_weight_enumerator` invariant.

!!! note "Native function-equivalence recovery"
    [`partition_refinement_equivalence`](@ref) and
    [`ccz_equivalence_certificate`](@ref) decide function equivalence directly
    using Kaleyski–Sunde (ePrint 2026/940), without an external code-equivalence
    solver. These matrices remain useful for invariants and downstream binary
    coding software. No general binary-code permutation search is provided.
    Native function recovery applies to the function-graph problem, not arbitrary
    supplied generator matrices. `code_weight_enumerator` is only a necessary condition:
    unequal enumerators prove inequivalence; equal enumerators do not prove it.

Row layout of every matrix (2n+1 rows): row 1 is the constant-1 row,
rows `2..n+1` carry the `x`-block bits (LSB first) and rows `n+2..2n+1`
the `F(x)`-block bits.
"""

"""
    ccz_matrix(F::SBox{N,T}) -> BitMatrix

The `(2n+1) × 2ⁿ` generator matrix of the CCZ-code of `F`. Column `x`
is `[1, x₀,…,xₙ₋₁,F(x)₀,…,F(x)ₙ₋₁]`, with LSB-first bits
within each block. This row order differs from `FunctionGraph` packing. (Edel-Pott Theorem 9.)
"""
function ccz_matrix(F::SBox{N,T}) where {N,T}
    n_size = 1 << N
    M = falses(2N + 1, n_size)
    @inbounds for x = 0:(n_size-1)
        M[1, x+1] = true
        v = UInt64(x) | (UInt64(F.lut[x+1]) << N)
        for b = 0:(2N-1)
            M[b+2, x+1] = ((v >> b) & 1) == 1
        end
    end
    return M
end

"""
    ea_matrix(F::SBox{N,T}) -> BitMatrix

The `(2n+1) × (2^{n+1} - 1)` generator matrix of the EA-code of `F`:
the CCZ-code columns `(1, x, F(x))` followed by the `2ⁿ - 1` columns
`(0, 0, y)` for `y ∈ 1:2ⁿ-1` — the `y` bits live in the `F(x)`-block
rows `n+2..2n+1`. `F` is EA-equivalent to `G` iff the codes of `F` and
`G` are permutation-equivalent (Edel-Pott Theorem 10).

!!! warning "Fixed column packing"
    Earlier versions packed the `y`-columns starting at the constant
    row or exchanged the input and output rows of the graph columns
    without exchanging the appended columns. Both errors change the code
    and can violate EA invariance. The graph and appended columns now use
    the same documented input/output row layout.
"""
function ea_matrix(F::SBox{N,T}) where {N,T}
    n_size = 1 << N
    ncols = n_size + (n_size - 1)
    M = falses(2N + 1, ncols)
    @inbounds for x = 0:(n_size-1)
        M[1, x+1] = true
        v = UInt64(x) | (UInt64(F.lut[x+1]) << N)
        for b = 0:(2N-1)
            M[b+2, x+1] = ((v >> b) & 1) == 1
        end
    end
    @inbounds for y = 1:(n_size-1)
        col = n_size + y
        for b = 0:(N-1)
            M[N+b+2, col] = ((UInt64(y) >> b) & 1) == 1
        end
    end
    return M
end

"""
    ae_matrix(F::SBox{N,T}) -> BitMatrix

The `(2n+1) × (2^{n+1} + 2ⁿ - 2)` generator matrix of the
affine-equivalence code of `F` (Calderini 2020, Section 4, code C₃):
columns `(1, x, F(x))` for all `x`, `(0, 0, y)` for `y ≠ 0`, and
`(0, z, 0)` for `z ≠ 0`. For non-permutations with nonzero
nonlinearity, `F` is affine-equivalent to `G` iff the codes are
permutation-equivalent; for permutations the codes are equivalent iff
`F` is affine-equivalent to `G` **or** to `G⁻¹` (Edel-Pott Theorem 11 /
Calderini 2020 Theorem 5).
"""
function ae_matrix(F::SBox{N,T}) where {N,T}
    n_size = 1 << N
    M = falses(2N + 1, 3n_size - 2)
    @inbounds for x = 0:(n_size-1)
        M[1, x+1] = true
        v = UInt64(x) | (UInt64(F.lut[x+1]) << N)
        for b = 0:(2N-1)
            M[b+2, x+1] = ((v >> b) & 1) == 1
        end
    end
    @inbounds for y = 1:(n_size-1)
        col = n_size + y
        for b = 0:(N-1)
            M[N+b+2, col] = ((UInt64(y) >> b) & 1) == 1
        end
    end
    @inbounds for z = 1:(n_size-1)
        col = 2n_size - 1 + z
        for b = 0:(N-1)
            M[b+2, col] = ((UInt64(z) >> b) & 1) == 1
        end
    end
    return M
end

"""
    ae_perm_matrix(F::SBox{N,T}) -> BitMatrix

The `(2n+1) × (2^{n+1} + 2ⁿ - 1)` generator matrix of the permutation
affine-equivalence code of `F` (Calderini 2020, Theorem 6, code C₄):
columns `(1, x, F(x))` for all `x`, `(0, 0, y)` for `y ≠ 0`, and
`(1, z, 0)` for **all** `z ∈ F₂ⁿ` (including `z = 0`). Two permutations
`F`, `G` are affine-equivalent iff `C₄(F)` is permutation-equivalent to
`C₄(G + b)` for some constant `b`. Unlike `ae_matrix`, this code
distinguishes `F` from `F⁻¹`. Throws for non-permutations.
"""
function ae_perm_matrix(F::SBox{N,T}) where {N,T}
    is_permutation(F) ||
        throw(ArgumentError("ae_perm_matrix: F must be a permutation"))
    n_size = 1 << N
    M = falses(2N + 1, 3n_size - 1)
    @inbounds for x = 0:(n_size-1)
        M[1, x+1] = true
        v = UInt64(x) | (UInt64(F.lut[x+1]) << N)
        for b = 0:(2N-1)
            M[b+2, x+1] = ((v >> b) & 1) == 1
        end
    end
    @inbounds for y = 1:(n_size-1)
        col = n_size + y
        for b = 0:(N-1)
            M[N+b+2, col] = ((UInt64(y) >> b) & 1) == 1
        end
    end
    @inbounds for z = 0:(n_size-1)
        col = 2n_size + z
        M[1, col] = true
        for b = 0:(N-1)
            M[b+2, col] = ((UInt64(z) >> b) & 1) == 1
        end
    end
    return M
end

"""
    code_weight_enumerator(M::AbstractMatrix{Bool}) -> Vector{Int}

Weight distribution `counts[w+1] = #codewords of Hamming weight w` of
the binary linear code spanned by the rows of `M`. Each distinct codeword is
counted once, independently of redundant/zero generator rows. Permutation-equivalent codes have equal
weight enumerators, so **unequal enumerators prove code inequivalence**;
the converse does not hold. Cost: row reduction followed by `2^rank` Gray-code
steps. The rank is capped at 30; large admitted ranks can still be expensive.
"""
function code_weight_enumerator(M::AbstractMatrix{Bool})
    reduced=BitMatrix(M)
    pivots,_=rref_f2!(reduced)
    r=length(pivots);len=size(M,2)
    r ≤ 30 || throw(ArgumentError("code_weight_enumerator: 2^$r codewords is too many"))
    nw = (len + 63) >>> 6
    rows = [zeros(UInt64, nw) for _ = 1:r]
    for i = 1:r, j = 1:len
        reduced[i, j] && (rows[i][((j-1)>>>6)+1] |= UInt64(1) << ((j - 1) & 63))
    end
    cur = zeros(UInt64, nw)
    counts = zeros(Int, len + 1)
    counts[1] = 1
    for g = 1:((1<<r)-1)
        row = rows[trailing_zeros(g)+1]
        wt = 0
        @inbounds for w = 1:nw
            cur[w] ⊻= row[w]
            wt += count_ones(cur[w])
        end
        counts[wt+1] += 1
    end
    return counts
end
