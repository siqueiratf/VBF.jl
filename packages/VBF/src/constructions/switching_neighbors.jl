"""
Switching-neighbour APN construction ([Edel and Pott, 2009](@cite Edel_200900)).

For an APN function `F : F₂ⁿ → F₂ⁿ` and a nonzero field element `u`, a
**`u`-switching neighbour** is an APN function of the form
`G(x) = F(x) ⊕ u·s(x)` for a Boolean function `s`, excluding the trivial
choices (`s` constant, linear, or one of `F`'s own `u`-coordinates).
[`switching_neighbors`](@ref) returns, for every nonzero `u`, the APN
functions in the `u`-switching space of `F`.

Switching-neighbour construction (Edel–Pott). The classical formulation
*samples* the constraint equations at random and retries when a kernel
element turns out non-APN; this implementation instead assembles the
**complete** system of necessary linear constraints (so the result is
deterministic and reproducible) and then filters the candidate neighbours by an
explicit APN check. The complete enumeration is `O(2^{3n})`, practical
for `n ≤ 7`.

The constraint for a fixed `u` lives over the `2ⁿ` unknowns `s(0..2ⁿ-1)`.
For each direction `a ≠ 0` and pair `x₁ ≠ x₂` (with `x₁ ≠ x₂ ⊕ a`) such
that `D_aF(x₁) ⊕ D_aF(x₂) = u`, the quadruple `{x₁⊕a, x₁, x₂⊕a, x₂}` of
`s`-values must sum to zero. The trivial neighbours (constant / linear /
the `n-1` non-`u` coordinates of `F`) are removed from the solution space.
"""

# Small homogeneous F₂ system: incremental insertion and kernel extraction.
mutable struct _SNSystem
    nvars::Int
    pivot_rows::Vector{BitVector}
    pivot_cols::Vector{Int}
    removed::Vector{BitVector}
end

_sn_system(nvars::Int) = _SNSystem(nvars, BitVector[], Int[], BitVector[])

# 0-based variable positions to a BitVector row, XOR-toggling so repeats cancel.
function _sn_rowof(nvars::Int, positions)
    row = falses(nvars)
    @inbounds for p in positions
        row[p+1] = !row[p+1]
    end
    row
end

function _sn_add_equation!(S::_SNSystem, positions)
    row = _sn_rowof(S.nvars, positions)
    @inbounds for t in eachindex(S.pivot_rows)
        row[S.pivot_cols[t]] && (row .⊻= S.pivot_rows[t])
    end
    lead = findfirst(row)
    if lead !== nothing
        push!(S.pivot_rows, row)
        push!(S.pivot_cols, lead)
    end
    return nothing
end

_sn_remove_solution!(S::_SNSystem, positions) =
    push!(S.removed, _sn_rowof(S.nvars, positions))

# RREF a set of BitVector rows in place; return parallel pivot columns.
function _sn_rref!(rows::Vector{BitVector})
    cols = Int[]
    keep = BitVector[]
    for r in rows
        row = copy(r)
        for t in eachindex(keep)
            row[cols[t]] && (row .⊻= keep[t])
        end
        lead = findfirst(row)
        if lead !== nothing
            push!(keep, row)
            push!(cols, lead)
        end
    end
    # back-reduce
    for i in eachindex(keep)
        pc = cols[i]
        for j in eachindex(keep)
            i == j && continue
            keep[j][pc] && (keep[j] .⊻= keep[i])
        end
    end
    return keep, cols
end

# Kernel basis of the system, with the removed solutions quotiented out.
function _sn_kernel(S::_SNSystem)
    prows, pcols = _sn_rref!(S.pivot_rows)
    pivot_set = Set(pcols)
    kernel = BitVector[]
    @inbounds for f = 1:S.nvars
        f in pivot_set && continue
        v = falses(S.nvars)
        v[f] = true
        for i in eachindex(prows)
            prows[i][f] && (v[pcols[i]] = true)
        end
        push!(kernel, v)
    end
    isempty(S.removed) && return kernel

    krows, kcols = _sn_rref!(copy(kernel))
    in_kernel = BitVector[]
    for r in S.removed
        row = copy(r)
        for t in eachindex(krows)
            row[kcols[t]] && (row .⊻= krows[t])
        end
        findfirst(row) === nothing && push!(in_kernel, r)   # r ∈ span(kernel)
    end
    isempty(in_kernel) && return kernel

    qrows = BitVector[]
    qcols = Int[]
    for r in in_kernel
        row = copy(r)
        for t in eachindex(qrows)
            row[qcols[t]] && (row .⊻= qrows[t])
        end
        lead = findfirst(row)
        lead !== nothing && (push!(qrows, row); push!(qcols, lead))
    end
    out = BitVector[]
    for k in kernel
        row = copy(k)
        for t in eachindex(qrows)
            row[qcols[t]] && (row .⊻= qrows[t])
        end
        lead = findfirst(row)
        if lead !== nothing
            push!(qrows, row)
            push!(qcols, lead)
            push!(out, k)
        end
    end
    return out
end

# All neighbours F ⊕ u·s for s in span(basis) \ {0}, keeping the APN ones.
function _sn_apn_coset(
    F::SBox{N,T},
    uu::T,
    basis::Vector{BitVector},
) where {N,T}
    n_size = 1 << N
    result = SBox{N,T}[]
    seen = Set{Vector{T}}()
    nb = length(basis)
    nb == 0 && return result
    @inbounds for combo = 1:((1<<nb)-1)
        lut = copy(F.lut)
        for j = 0:(nb-1)
            ((combo >> j) & 1) == 1 || continue
            bj = basis[j+1]
            for x = 0:(n_size-1)
                bj[x+1] && (lut[x+1] ⊻= uu)
            end
        end
        lut in seen && continue
        push!(seen, lut)
        G = SBox{N,T}(lut)
        differential_uniformity(G) ≤ 2 && push!(result, G)
    end
    return result
end

"""
    switching_neighbors(F::SBox{N,T}) -> Vector{Vector{SBox{N,T}}}

For an APN function `F`, the switching neighbours grouped by field
element: entry `u` (for `u = 1 … 2ⁿ-1`) is the vector of APN functions
`G = F ⊕ u·s` with `s` a non-trivial Boolean function in `F`'s
`u`-switching space. The returned vector has length `2ⁿ-1`.

Throws `ArgumentError` if `F` is not APN. See the module docstring for the
deterministic-vs-sampled difference.
"""
function switching_neighbors(F::SBox{N,T}) where {N,T}
    differential_uniformity(F) ≤ 2 ||
        throw(ArgumentError("switching_neighbors: F must be APN"))
    n_size = 1 << N
    flut = F.lut

    # One constraint system per nonzero field element u (1-based: systems[u]).
    systems = [_sn_system(n_size) for _ = 1:(n_size-1)]

    # Exclude trivial neighbours: constant, linear, and F's own coordinates.
    all_positions = collect(0:(n_size-1))
    linear_positions =
        [Int[x for x = 0:(n_size-1) if (x >> i) & 1 == 1] for i = 0:(N-1)]
    for uu = 1:(n_size-1)
        S = systems[uu]
        _sn_remove_solution!(S, all_positions)            # constant function
        for lp in linear_positions                        # linear coordinates
            _sn_remove_solution!(S, lp)
        end
        Minv = inv(F2LinearMap{N,T}(complete_basis(T[T(uu)], N)))
        temp_s = compose(Minv, F)                          # M⁻¹ ∘ F
        for i = 1:(N-1)  # F's non-u coordinates
            pos = Int[x for x = 0:(n_size-1) if (temp_s.lut[x+1] >> i) & 1 == 1]
            _sn_remove_solution!(S, pos)
        end
    end

    # Complete necessary-constraint system.
    @inbounds for a = 1:(n_size-1)
        for x1 = 0:(n_size-1)
            f_ax1 = flut[(x1⊻a)+1] ⊻ flut[x1+1]
            for x2 = 0:(n_size-1)
                x1 == x2 && continue
                x1 == (x2 ⊻ a) && continue
                target = f_ax1 ⊻ flut[(x2⊻a)+1] ⊻ flut[x2+1]
                target == 0 && continue
                _sn_add_equation!(
                    systems[Int(target)],
                    (x1 ⊻ a, x1, x2 ⊻ a, x2),
                )
            end
        end
    end

    result = Vector{Vector{SBox{N,T}}}(undef, n_size - 1)
    for uu = 1:(n_size-1)
        basis = _sn_kernel(systems[uu])
        result[uu] = _sn_apn_coset(F, T(uu), basis)
    end
    return result
end
