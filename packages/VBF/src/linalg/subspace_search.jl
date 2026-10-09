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

The DFS is correct for any dimension. The GJB constraints already prune
most of the search; an MSB-spectrum bound on the candidate leading bits
would prune further but is not used here.
"""

# Leading-1 bit position (LSB-0). Returns -1 for v == 0.
@inline function _leading_bit_pos(v::UInt32)
    v == zero(UInt32) && return -1
    return 31 - leading_zeros(v)
end

@inline function _gjb_clean(prev_basis::Vector{UInt32}, b::UInt32, b_msb::Int)
    @inbounds for prev_b in prev_basis
        prev_msb = _leading_bit_pos(prev_b)
        ((b >> prev_msb) & UInt32(1)) == UInt32(1) && return false
        ((prev_b >> b_msb) & UInt32(1)) == UInt32(1) && return false
    end
    return true
end

# The unbounded entry point specializes these checks away. A bounded walk also
# checks inside candidate/span loops, since a dead branch may never recurse.
mutable struct _SubspaceSearchBudget
    max_nodes::Int
    max_subspaces::Int
    timeout_seconds::Float64
    started::UInt64
    nodes::Int
    stop_reason::Union{Nothing,Symbol}
end

@inline _subspace_check!(::Nothing) = true
@inline _subspace_visit!(::Nothing) = true
@inline _subspace_record!(::Nothing, bases) = true

@inline function _subspace_check!(budget::_SubspaceSearchBudget)
    budget.stop_reason === nothing || return false
    if (time_ns() - budget.started) / 1.0e9 >= budget.timeout_seconds
        budget.stop_reason = :time
        return false
    end
    return true
end

@inline function _subspace_visit!(budget::_SubspaceSearchBudget)
    _subspace_check!(budget) || return false
    if budget.nodes >= budget.max_nodes
        budget.stop_reason = :nodes
        return false
    end
    budget.nodes += 1
    return true
end

@inline function _subspace_record!(budget::_SubspaceSearchBudget, bases)
    if length(bases) >= budget.max_subspaces
        budget.stop_reason = :solutions
        return false
    end
    return true
end

# Recursive DFS; returns false if a budget stops the walk. Both entry points
# share the same candidate order and Gauss-Jordan/span-extension mathematics.
function _subspace_dfs!(
    bases::Vector{Vector{UInt32}},
    z_sorted::Vector{UInt32},
    indicator::Set{UInt32},
    dim::Int,
    current_basis::Vector{UInt32},
    current_span::Vector{UInt32},
    max_leading_bit::Int,
    budget = nothing,
)
    _subspace_visit!(budget) || return false
    k = length(current_basis)
    if k == dim
        push!(bases, copy(current_basis))
        return _subspace_record!(budget, bases)
    end

    @inbounds for b in z_sorted
        _subspace_visit!(budget) || return false
        b_msb = _leading_bit_pos(b)
        b_msb < max_leading_bit || continue
        # Enforce GJB form against the existing basis.
        _gjb_clean(current_basis, b, b_msb) || continue
        # Verify span extension: for every v ∈ current_span, b ⊕ v ∈ z.
        ok = true
        for v in current_span
            _subspace_check!(budget) || return false
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
        for i = 1:old_span_size
            _subspace_check!(budget) || return false
            current_span[old_span_size+i] = current_span[i] ⊻ b
        end
        completed = _subspace_dfs!(
            bases,
            z_sorted,
            indicator,
            dim,
            current_basis,
            current_span,
            b_msb,
            budget,
        )
        # Backtrack: restore basis and span.
        pop!(current_basis)
        resize!(current_span, old_span_size)
        completed || return false
    end
    return true
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
julia> using VBF

julia> bases = VBF.extract_linear_subspaces(UInt32[1, 2, 3], 2; max_bits = 2);

julia> length(bases) == 1   # the unique 2-dim subspace {0, 1, 2, 3}
true

julia> bases[1] == UInt32[2, 1]
true
```
"""
function extract_linear_subspaces(
    z::Vector{UInt32},
    dim::Int;
    max_bits::Int = 32,
)
    dim ≥ 0 || throw(
        ArgumentError("extract_linear_subspaces: dim must be ≥ 0, got $dim"),
    )
    dim == 0 && return [UInt32[]]
    z_sorted = sort(filter(!=(UInt32(0)), z); rev = true)
    isempty(z_sorted) && return Vector{Vector{UInt32}}()
    indicator = Set(z_sorted)
    bases = Vector{Vector{UInt32}}()
    current_basis = UInt32[]
    current_span = UInt32[0]
    _subspace_dfs!(
        bases,
        z_sorted,
        indicator,
        dim,
        current_basis,
        current_span,
        max_bits,
    )
    return bases
end

"""
    extract_linear_subspaces_bounded(z::Vector{UInt32}, dim::Int;
        max_bits::Int = 32, max_nodes::Int = 10^6,
        max_subspaces::Int = typemax(Int), timeout_seconds::Real = 60)
        -> SearchOutcome{Vector{UInt32}}

Bounded version of [`extract_linear_subspaces`](@ref), with identical basis
ordering. [`search_solutions`](@ref) contains canonical Gauss-Jordan bases.
An [`Exhausted`](@ref) result certifies that every subspace was enumerated;
[`BudgetHit`](@ref) contains only a partial list and certifies no coverage.

`max_nodes` counts DFS entries and examined candidates, including rejected
candidates. Time checks also occur inside span-extension loops. All bounds
must be nonnegative, and `max_bits` must be between 0 and 32. A zero node,
solution, or time bound stops immediately. Reaching `max_subspaces` returns
`BudgetHit(:solutions)` conservatively, even if the last recorded basis happens
to be the final solution. Set `timeout_seconds = Inf` to disable the time bound.

The set is interpreted as `z ∪ {0}`, and points outside `max_bits` cannot
participate in a returned basis. Bounds cover the search and input preparation;
sorting itself is not interruptible.
"""
function extract_linear_subspaces_bounded(
    z::Vector{UInt32},
    dim::Int;
    max_bits::Int = 32,
    max_nodes::Int = 10^6,
    max_subspaces::Int = typemax(Int),
    timeout_seconds::Real = 60,
)
    dim >= 0 || throw(ArgumentError("dim must be nonnegative"))
    0 <= max_bits <= 32 || throw(ArgumentError("max_bits must be between 0 and 32"))
    max_nodes >= 0 || throw(ArgumentError("max_nodes must be nonnegative"))
    max_subspaces >= 0 || throw(ArgumentError("max_subspaces must be nonnegative"))
    timeout_seconds >= 0 || throw(ArgumentError("timeout_seconds must be nonnegative"))
    started = time_ns()
    budget = _SubspaceSearchBudget(
        max_nodes, max_subspaces, Float64(timeout_seconds), started, 0, nothing,
    )
    region = SearchRegion(
        :linear_subspaces, "dimension-$dim";
        params = Dict{String,Any}("dimension" => dim, "max_bits" => max_bits),
    )
    bases = Vector{Vector{UInt32}}()
    # Establish immediate stops before handling mathematically trivial cases.
    if _subspace_check!(budget)
        if max_nodes == 0
            budget.stop_reason = :nodes
        elseif max_subspaces == 0
            budget.stop_reason = :solutions
        else
            z_sorted = sort(filter(!=(UInt32(0)), z); rev = true)
            if _subspace_check!(budget)
                _subspace_dfs!(
                    bases, z_sorted, Set(z_sorted), dim, UInt32[], UInt32[0],
                    max_bits, budget,
                )
            end
        end
    end
    elapsed = (time_ns() - started) / 1.0e9
    if budget.stop_reason === nothing
        return Exhausted(region, bases; nodes_visited = budget.nodes, elapsed_seconds = elapsed)
    end
    return BudgetHit(
        StopPoint(budget.stop_reason), region, bases;
        nodes_visited = budget.nodes, elapsed_seconds = elapsed,
    )
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
        for i = 1:length(span)
            new_span[i] = span[i]
            new_span[length(span)+i] = span[i] ⊻ b
        end
        span = new_span
    end
    return span
end
