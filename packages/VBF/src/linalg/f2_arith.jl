"""
F₂ⁿ arithmetic primitives.

This module owns the lowest-level bit operations and the linear-algebra
primitives over F₂ that the equivalence layer needs. Nothing here calls
into `statistics/` or `equivalence/`; everything above this layer calls
through these functions.

# Bit primitives
- [`parity`](@ref)        — popcount mod 2.
- [`f2_dot`](@ref)        — F₂ inner product.

# F₂ matrix algebra (rows packed into unsigned integers)
- [`gauss_jordan!`](@ref) — in-place reduced row echelon, returns rank.
- [`rank_f2`](@ref)       — non-destructive rank.
- [`linear_basis`](@ref)  — Gauss-reduced basis of the row span.
- [`is_in_span`](@ref)    — membership test under an already-reduced basis.
- [`complete_basis`](@ref)— extend a partial basis to a basis of F₂ᴺ.
"""

# --- bit primitives -----------------------------------------------------------

"""
    parity(x) -> 0 or 1

Hamming weight of `x` taken mod 2.
"""
@inline parity(x::Integer) = count_ones(x) & 1
@inline parity(x::Bool) = Int(x)

"""
    f2_dot(a, b) -> 0 or 1

F₂ inner product of two bit-vectors packed into unsigned integers.
"""
@inline f2_dot(a::Integer, b::Integer) = parity(a & b)

# --- Gauss-Jordan on packed-row F₂ matrices -----------------------------------

"""
    gauss_jordan!(rows::Vector{T}; nbits::Integer = 8*sizeof(T)) where {T<:Unsigned}

In-place reduced row echelon form over F₂. Each `rows[i]` is treated as
a length-`nbits` bit-vector (bit `c` is column `c`). Returns the rank.

After the call:
- `rows[1:rank]` is the reduced echelon basis (pivot bits are unique to
  their row; each pivoted row has the form `1 0 … 0 1 …`).
- `rows[rank+1:end]` is zero.

The pivot column order is LSB → MSB.
"""
function gauss_jordan!(
    rows::Vector{T};
    nbits::Integer = 8 * sizeof(T),
) where {T<:Unsigned}
    @assert 1 ≤ nbits ≤ 8 * sizeof(T)
    n = length(rows)
    rank = 0
    @inbounds for c = 0:(nbits-1)
        bit = T(1) << c
        # find pivot row in unprocessed range
        p = 0
        for i = (rank+1):n
            if (rows[i] & bit) != zero(T)
                p = i
                break
            end
        end
        p == 0 && continue
        rows[rank+1], rows[p] = rows[p], rows[rank+1]
        pivot = rows[rank+1]
        # eliminate this bit from every other row
        for i = 1:n
            i == rank + 1 && continue
            if (rows[i] & bit) != zero(T)
                rows[i] ⊻= pivot
            end
        end
        rank += 1
    end
    rank
end

"""
    rank_f2(rows::AbstractVector{<:Unsigned}; nbits = 8*sizeof(eltype(rows))) -> Int

F₂ rank of a matrix given as a vector of row-bitmasks. Non-destructive.
"""
function rank_f2(
    rows::AbstractVector{T};
    nbits::Integer = 8 * sizeof(T),
) where {T<:Unsigned}
    gauss_jordan!(collect(rows); nbits)
end

"""
    linear_basis(rows::AbstractVector{<:Unsigned}; nbits = 8*sizeof(eltype(rows)))
        -> Vector{eltype(rows)}

Reduced row echelon basis of the F₂ row span of `rows`. The returned
vector has length equal to the rank; zero rows have been dropped.
"""
function linear_basis(
    rows::AbstractVector{T};
    nbits::Integer = 8 * sizeof(T),
) where {T<:Unsigned}
    work = collect(rows)
    r = gauss_jordan!(work; nbits)
    work[1:r]
end

"""
    is_in_span(v::Unsigned, basis::AbstractVector{<:Unsigned};
               nbits = 8*sizeof(eltype(basis))) -> Bool

`true` iff `v` is in the F₂ span of `basis`. Assumes `basis` is already
in reduced row echelon form (e.g., the output of [`linear_basis`](@ref));
*not* a `rank_f2(basis ∪ {v}) == rank_f2(basis)` check.

Implementation: for each basis row in order, if the pivot bit is set in
`v`, XOR the row into `v`. At the end, `v == 0` iff it was in span.
"""
function is_in_span(
    v::T,
    basis::AbstractVector{T};
    nbits::Integer = 8 * sizeof(T),
) where {T<:Unsigned}
    x = v
    @inbounds for row in basis
        row == zero(T) && continue
        pivot_bit_idx = trailing_zeros(row)
        pivot_bit_idx ≥ nbits && break
        if (x >> pivot_bit_idx) & T(1) == T(1)
            x ⊻= row
        end
    end
    x == zero(T)
end

"""
    complete_basis(partial::AbstractVector{T}, nbits::Integer) -> Vector{T} where {T<:Unsigned}

Extend `partial` (a reduced-row-echelon basis of some F₂ subspace) to a
basis of all of F₂^{nbits}. Adds standard basis vectors `e_i = 2^i`
greedily; throws if `partial` was not already independent.

Returns a fresh `Vector{T}` of length `nbits` whose first
`length(partial)` rows are the original basis.
"""
function complete_basis(
    partial::AbstractVector{T},
    nbits::Integer,
) where {T<:Unsigned}
    1 ≤ nbits ≤ 8 * sizeof(T) ||
        throw(ArgumentError("complete_basis: nbits=$nbits out of range for $T"))
    work = collect(partial)
    r = gauss_jordan!(work; nbits)
    r == length(partial) || throw(
        ArgumentError(
            "complete_basis: input is not linearly independent (rank $r of $(length(partial)) rows)",
        ),
    )
    out = collect(partial)
    sizehint!(out, nbits)
    for c = 0:(nbits-1)
        e = T(1) << c
        is_in_span(e, work; nbits) && continue
        push!(out, e)
        # extend work too so subsequent checks see the new vector
        push!(work, e)
        gauss_jordan!(work; nbits)
    end
    @assert length(out) == nbits "complete_basis: produced $(length(out)) vectors for nbits=$nbits"
    out
end

"""
    complete_basis_reversed(partial::AbstractVector{T}, nbits::Integer) -> Vector{T} where {T<:Unsigned}

Extend `partial` (an independent F₂ set) to a basis of F₂^{nbits}, with
the completion vectors **prepended**: the returned vector's *last*
`length(partial)` rows are the original input, the first rows are
greedily-chosen standard-basis vectors `2^c`.

This is the reversed counterpart of [`complete_basis`](@ref) and underlies
[`generating_affine_map_r`](@ref). Throws if `partial` was not already
linearly independent.
"""
function complete_basis_reversed(
    partial::AbstractVector{T},
    nbits::Integer,
) where {T<:Unsigned}
    1 ≤ nbits ≤ 8 * sizeof(T) || throw(
        ArgumentError(
            "complete_basis_reversed: nbits=$nbits out of range for $T",
        ),
    )
    work = collect(partial)
    r = gauss_jordan!(work; nbits)
    r == length(partial) || throw(
        ArgumentError(
            "complete_basis_reversed: input is not linearly independent (rank $r of $(length(partial)) rows)",
        ),
    )
    prefix = T[]
    for c = 0:(nbits-1)
        length(prefix) + length(partial) == nbits && break
        e = T(1) << c
        is_in_span(e, work; nbits) && continue
        pushfirst!(prefix, e)
        push!(work, e)
        gauss_jordan!(work; nbits)
    end
    @assert length(prefix) + length(partial) == nbits "complete_basis_reversed: produced $(length(prefix) + length(partial)) vectors for nbits=$nbits"
    return vcat(prefix, collect(partial))
end
