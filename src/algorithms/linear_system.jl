"""
F₂ matrix algebra needed by the equivalence layer.

Builds on `f2/arith.jl`'s `gauss_jordan!` / `linear_basis` /
`is_in_span` / `complete_basis` to provide higher-level operations:

- `Base.inv(L::F2LinearMap)` — multiplicative inverse of an F₂-linear map.
- `compose(L1, L2)` / `Base.:∘(L1, L2)` — `L1 ∘ L2` for `F2LinearMap`s
  (and `F::SBox ∘ L::F2LinearMap`, `L ∘ F`).
- `is_invertible(L::F2LinearMap)` — rank == `N`.
- `solve_f2(A, b)` — solve `A · x = b` for `x ∈ F₂ᴺ`; returns `nothing`
  if inconsistent.
- `kernel_f2(A; nbits)` — basis of the nullspace.

Everything operates on bit-packed unsigned integers (rows of bits) or
on `F2LinearMap` / `SBox` instances directly. Allocation-free hot path
where reasonable.
"""

# ----------------------------------------------------------------------------
# F2LinearMap inversion + composition
# ----------------------------------------------------------------------------

"""
    is_invertible(L::F2LinearMap{N, T}) where {N, T} -> Bool

`true` iff the `N×N` matrix whose columns are `L.cols` has full rank
over F₂.
"""
function is_invertible(L::F2LinearMap{N, T}) where {N, T}
    work = collect(L.cols)
    rank_f2(work; nbits = N) == N
end

"""
    Base.inv(L::F2LinearMap{N, T}) -> F2LinearMap{N, T}

Multiplicative inverse of `L`. Throws `ArgumentError` if `L` is
singular (`is_invertible(L) == false`).

The inverse is computed by row-reducing `[Mᵀ | I]` to `[I | (Mᵀ)⁻¹]`
on the transpose of the column-vector representation; the result is
transposed back to the column-vector form.
"""
function Base.inv(L::F2LinearMap{N, T}) where {N, T}
    # Rows of M^T: row i = bit i of cols[1..N] concatenated.
    # rows_transposed[i+1] has bit j set iff bit i of L.cols[j+1] is 1.
    Tcap = 8 * sizeof(T)
    rows = Vector{T}(undef, N)
    @inbounds for i in 0:N - 1
        r = zero(T)
        for j in 0:N - 1
            if ((L.cols[j + 1] >> i) & T(1)) == T(1)
                r |= T(1) << j
            end
        end
        rows[i + 1] = r
    end
    # Augment with identity in bits N..2N-1.  Width 2N must fit in T.
    if 2N > Tcap
        # Operate on a wider type
        return _inv_wide(L)
    end
    @inbounds for i in 0:N - 1
        rows[i + 1] |= T(1) << (N + i)
    end
    # Row-reduce the N×2N matrix.  Pivot column c then for c = 0..N-1:
    rank = 0
    @inbounds for c in 0:N - 1
        bit = T(1) << c
        # find pivot
        p = 0
        for i in (rank + 1):N
            if (rows[i] & bit) != zero(T)
                p = i; break
            end
        end
        p == 0 &&
            throw(ArgumentError("inv(L::F2LinearMap): map is singular (rank < $N)"))
        rows[rank + 1], rows[p] = rows[p], rows[rank + 1]
        pivot = rows[rank + 1]
        for i in 1:N
            i == rank + 1 && continue
            if (rows[i] & bit) != zero(T)
                rows[i] ⊻= pivot
            end
        end
        rank += 1
    end
    # Now bits N..2N-1 of each row hold the inverse-transpose. Transpose back.
    inv_cols = zeros(T, N)
    @inbounds for i in 0:N - 1
        right = (rows[i + 1] >> N) & ((T(1) << N) - T(1))
        for j in 0:N - 1
            if ((right >> j) & T(1)) == T(1)
                inv_cols[j + 1] |= T(1) << i
            end
        end
    end
    F2LinearMap{N, T}(inv_cols)
end

# Fallback for the (rare) case where 2N > 8·sizeof(T): convert to UInt128.
function _inv_wide(L::F2LinearMap{N, T}) where {N, T}
    Lw = F2LinearMap{N, UInt128}(UInt128.(L.cols))
    invw = inv(Lw)
    F2LinearMap{N, T}(T.(invw.cols))
end

"""
    compose(L1::F2LinearMap, L2::F2LinearMap) -> F2LinearMap

`L1 ∘ L2`: the F₂-linear map `x ↦ L1(L2(x))`. Both maps must have the
same `N` and storage type. Implemented as
`compose(L1, L2).cols[j+1] = L1(L2.cols[j+1])`.
"""
function compose(L1::F2LinearMap{N, T}, L2::F2LinearMap{N, T}) where {N, T}
    F2LinearMap{N, T}(T[L1(L2.cols[j + 1]) for j in 0:N - 1])
end

Base.:∘(L1::F2LinearMap{N, T}, L2::F2LinearMap{N, T}) where {N, T} = compose(L1, L2)

"""
    compose(F::SBox, L::F2LinearMap) -> SBox
    compose(L::F2LinearMap, F::SBox) -> SBox

Function-composition of an `SBox` with an `F2LinearMap`. `F ∘ L`
applies `L` first, then `F`; `L ∘ F` is the reverse. Both return a
fresh `SBox` of the same `(N, T)`.
"""
function compose(F::SBox{N, T}, L::F2LinearMap{N, T}) where {N, T}
    n = 1 << N
    SBox{N, T}(T[F.lut[L(x) + 1] for x in 0:n - 1])
end

function compose(L::F2LinearMap{N, T}, F::SBox{N, T}) where {N, T}
    n = 1 << N
    SBox{N, T}(T[L(F.lut[x + 1]) for x in 0:n - 1])
end

Base.:∘(F::SBox{N, T}, L::F2LinearMap{N, T}) where {N, T} = compose(F, L)
Base.:∘(L::F2LinearMap{N, T}, F::SBox{N, T}) where {N, T} = compose(L, F)

# ----------------------------------------------------------------------------
# Solving A·x = b over F₂
# ----------------------------------------------------------------------------

"""
    solve_f2(A::AbstractVector{T}, b::T; nbits::Integer = 8 * sizeof(T)) where {T<:Unsigned}
        -> Union{T, Nothing}

Solve `A · x = b` over F₂ where each `A[i]` is a row-bitmask (bit `j` of
`A[i]` is the `(i, j)` entry of `A`) and `b` is a column-vector encoded
as a single `T` (bit `i` is the `i`-th entry of `b`). Returns one
solution `x` if any exist, or `nothing` if the system is inconsistent.

`nbits` is the matrix width (number of columns of `A`); rows beyond
`nbits` of any `A[i]` are ignored.
"""
function solve_f2(A::AbstractVector{T}, b::T;
                   nbits::Integer = 8 * sizeof(T)) where {T<:Unsigned}
    @assert 1 ≤ nbits ≤ 8 * sizeof(T)
    n_rows = length(A)
    # Augment: row i becomes A[i] | (bit_i_of_b << nbits)
    work = Vector{T}(undef, n_rows)
    @inbounds for i in 1:n_rows
        bit_b = (b >> (i - 1)) & T(1)
        work[i] = A[i] | (bit_b << nbits)
    end
    # Reduce on the first `nbits` columns; track pivots.
    rank = 0
    pivot_col_for_row = fill(-1, n_rows)
    @inbounds for c in 0:nbits - 1
        bit = T(1) << c
        p = 0
        for i in (rank + 1):n_rows
            if (work[i] & bit) != zero(T)
                p = i; break
            end
        end
        p == 0 && continue
        work[rank + 1], work[p] = work[p], work[rank + 1]
        pivot = work[rank + 1]
        for i in 1:n_rows
            i == rank + 1 && continue
            if (work[i] & bit) != zero(T)
                work[i] ⊻= pivot
            end
        end
        pivot_col_for_row[rank + 1] = c
        rank += 1
    end
    # Inconsistency: any row with all-zero left side but non-zero augmented bit
    @inbounds for i in 1:n_rows
        left = work[i] & ((T(1) << nbits) - T(1))
        right = (work[i] >> nbits) & T(1)
        if left == zero(T) && right == T(1)
            return nothing
        end
    end
    # Back-substitution: x[pivot_col] = right-augmented bit; free vars stay 0
    x = zero(T)
    @inbounds for i in 1:rank
        col = pivot_col_for_row[i]
        right = (work[i] >> nbits) & T(1)
        right == T(1) && (x |= T(1) << col)
    end
    x
end

"""
    kernel_f2(A::AbstractVector{T}; nbits::Integer = 8 * sizeof(T)) -> Vector{T}

Basis of `{x ∈ F₂ⁿ : A · x = 0}` where `A` is given as a row-bitmask
vector. Returns each basis vector as a `T`. The returned set has
exactly `nbits - rank_f2(A)` elements.
"""
function kernel_f2(A::AbstractVector{T};
                    nbits::Integer = 8 * sizeof(T)) where {T<:Unsigned}
    @assert 1 ≤ nbits ≤ 8 * sizeof(T)
    work = collect(A)
    n_rows = length(work)
    rank = 0
    pivot_col_for_row = fill(-1, n_rows)
    is_pivot_col = falses(nbits)
    @inbounds for c in 0:nbits - 1
        bit = T(1) << c
        p = 0
        for i in (rank + 1):n_rows
            if (work[i] & bit) != zero(T)
                p = i; break
            end
        end
        p == 0 && continue
        work[rank + 1], work[p] = work[p], work[rank + 1]
        pivot = work[rank + 1]
        for i in 1:n_rows
            i == rank + 1 && continue
            if (work[i] & bit) != zero(T)
                work[i] ⊻= pivot
            end
        end
        pivot_col_for_row[rank + 1] = c
        is_pivot_col[c + 1] = true
        rank += 1
    end
    # For each free column f, basis vector v has bit f set, and
    # bit (pivot_col of row i) set iff row i has bit f set after reduction.
    out = T[]
    @inbounds for f in 0:nbits - 1
        is_pivot_col[f + 1] && continue
        v = T(1) << f
        for i in 1:rank
            if (work[i] >> f) & T(1) == T(1)
                v |= T(1) << pivot_col_for_row[i]
            end
        end
        push!(out, v)
    end
    out
end
