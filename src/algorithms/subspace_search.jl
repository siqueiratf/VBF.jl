"""
Enumeration of F₂-linear subspaces of a given dimension contained in a
vector set.

Used by the CCZ-equivalence layer to enumerate the n-dimensional
F₂-linear subspaces of the Walsh-zeroes set `Z(F)`. Each such subspace
corresponds to one EA-class in the CCZ-class of `F` — the heart of the
Canteaut-Perrin framework.

A simple recursive DFS that enforces **Gauss-Jordan basis (GJB) form**
to enumerate each subspace exactly once:

- Basis vectors `b_1, b_2, …, b_dim` have strictly decreasing leading-1
  bit positions `p_1 > p_2 > ⋯ > p_dim`.
- For each basis vector `b_i` and `j ≠ i`, bit `p_j` of `b_i` is `0`
  (i.e., the leading bit of one basis vector clears that column in
  every other basis vector).

The pure-DFS port is correct for any dimension; the MSB-spectrum
pruning from sboxU's `cpp/algorithms/spaceSearch.cpp` is an
optimization that further prunes the search but is not yet ported
(intended follow-up if `n ≥ 7` performance becomes a concern).
"""

# Leading-1 bit position (LSB-0). Returns -1 for v == 0.
@inline function _leading_bit_pos(v::UInt32)
    v == zero(UInt32) && return -1
    return 31 - leading_zeros(v)
end

# Helper: does `prev_basis` violate GJB form with new vector `b`?
# Specifically, for every `prev_b` in current basis with leading bit `p_prev`,
#   - bit `p_prev` of `b` must be 0   (b cannot have 1 at prev's leading bit)
#   - bit `b_msb` of `prev_b` must be 0  (prev cannot have 1 at b's leading bit)
@inline function _gjb_clean(prev_basis::Vector{UInt32}, b::UInt32, b_msb::Int)
    @inbounds for prev_b in prev_basis
        prev_msb = _leading_bit_pos(prev_b)
        ((b >> prev_msb) & UInt32(1)) == UInt32(1) && return false
        ((prev_b >> b_msb) & UInt32(1)) == UInt32(1) && return false
    end
    return true
end

# Recursive DFS. Mutates `bases` (the output vector of GJB bases) and
# threads `current_basis` and `current_span` as mutable state.
function _subspace_dfs!(
    bases::Vector{Vector{UInt32}},
    z_sorted::Vector{UInt32},
    indicator::Set{UInt32},
    dim::Int,
    current_basis::Vector{UInt32},
    current_span::Vector{UInt32},
    max_leading_bit::Int,
)
    k = length(current_basis)
    if k == dim
        push!(bases, copy(current_basis))
        return
    end

    @inbounds for b in z_sorted
        b_msb = _leading_bit_pos(b)
        b_msb < max_leading_bit || continue
        # Enforce GJB form against the existing basis.
        _gjb_clean(current_basis, b, b_msb) || continue
        # Verify span extension: for every v ∈ current_span, b ⊕ v ∈ z.
        ok = true
        for v in current_span
            v_xor_b = v ⊻ b
            if !(v_xor_b in indicator)
                ok = false
                break
            end
        end
        ok || continue
        # Extend basis and span.
        push!(current_basis, b)
        old_span_size = length(current_span)
        resize!(current_span, 2 * old_span_size)
        for i in 1:old_span_size
            current_span[old_span_size + i] = current_span[i] ⊻ b
        end
        _subspace_dfs!(bases, z_sorted, indicator, dim,
                       current_basis, current_span, b_msb)
        # Backtrack: restore basis and span.
        pop!(current_basis)
        resize!(current_span, old_span_size)
    end
end

"""
    extract_linear_subspaces(z::Vector{UInt32}, dim::Int; max_bits::Int = 32)
        -> Vector{Vector{UInt32}}

Enumerate every F₂-linear subspace of dimension `dim` contained in the
set `z ∪ {0}` (subspaces always include `0`; `z` itself need not).
Each subspace is returned as its canonical Gauss-Jordan basis — a
`Vector{UInt32}` of length `dim` with strictly decreasing leading-bit
positions and pairwise-cleared leading-bit columns.

`max_bits` is the ambient bit width; for Walsh-zeroes of an `n`-bit
SBox use `max_bits = 2n`.

# Examples

```jldoctest
julia> using BFA

julia> bases = BFA.extract_linear_subspaces(UInt32[1, 2, 3], 2; max_bits = 2);

julia> length(bases) == 1   # the unique 2-dim subspace {0, 1, 2, 3}
true

julia> bases[1] == UInt32[2, 1]
true
```
"""
function extract_linear_subspaces(
    z::Vector{UInt32}, dim::Int; max_bits::Int = 32,
)
    dim ≥ 0 ||
        throw(ArgumentError("extract_linear_subspaces: dim must be ≥ 0, got $dim"))
    dim == 0 && return [UInt32[]]
    z_sorted = sort(filter(!=(UInt32(0)), z); rev = true)
    isempty(z_sorted) && return Vector{Vector{UInt32}}()
    indicator = Set(z_sorted)
    bases = Vector{Vector{UInt32}}()
    current_basis = UInt32[]
    current_span = UInt32[0]
    _subspace_dfs!(bases, z_sorted, indicator, dim,
                   current_basis, current_span, max_bits)
    return bases
end

"""
    span_from_basis(basis::Vector{UInt32}) -> Vector{UInt32}

The full linear span of a basis: `2^length(basis)` elements including
`0`.
"""
function span_from_basis(basis::Vector{UInt32})
    span = UInt32[0]
    @inbounds for b in basis
        new_span = Vector{UInt32}(undef, 2 * length(span))
        for i in 1:length(span)
            new_span[i] = span[i]
            new_span[length(span) + i] = span[i] ⊻ b
        end
        span = new_span
    end
    return span
end
