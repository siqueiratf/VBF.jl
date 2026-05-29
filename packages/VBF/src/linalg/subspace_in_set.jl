"""
F₂ linear subspaces *contained in a given set* of field elements — as opposed to
[`extract_linear_subspaces`](@ref), which enumerates subspaces of the whole
space. These are the building blocks of the linear-equivalence invariants
`nonbent_signature` and `image_subspaces` (after Kaleyski's VBF library): the
number of subspaces of each dimension whose nonzero elements all lie in the set.

A subspace is represented by the sorted vector of its `2ᵏ` elements (including
`0`); a set is any collection of elements of `GF(2ⁿ) = 0:2ⁿ-1`.
"""

"""
    smallest_basis(subspace) -> Vector{Int}

The lexicographically-smallest basis of an F₂ subspace given as a (sorted)
vector of its elements: greedily take each element not yet spanned.
"""
function smallest_basis(subspace::AbstractVector{<:Integer})
    basis = Int[]
    spanned = Set{Int}((0,))
    for x in subspace
        xi = Int(x)
        if !(xi in spanned)
            push!(basis, xi)
            for g in collect(spanned)
                push!(spanned, g ⊻ xi)
            end
        end
    end
    basis
end

_set_mask(S, n) = (m = falses(1 << Int(n)); for s in S; m[Int(s) + 1] = true; end; m)

"""
    find_2d_subspaces(S, n) -> Vector{Vector{Int}}

Every 2-dimensional F₂ subspace `{0, x, y, x⊕y}` whose nonzero elements lie in
the set `S ⊆ GF(2ⁿ)`, each as the sorted 4-element vector.
"""
function find_2d_subspaces(S::AbstractVector{<:Integer}, n::Integer)
    inset = _set_mask(S, n)
    out = Vector{Int}[]
    L = length(S)
    @inbounds for i in 1:L
        x = Int(S[i])
        for j in i + 1:L
            y = Int(S[j]); z = x ⊻ y
            if x < z && y < z && inset[z + 1]
                push!(out, sort!([0, x, y, z]))   # z is the largest; each 2-space found once
            end
        end
    end
    out
end

"""
    expand_subspaces(S, subspaces, n) -> Vector{Vector{Int}}

Given a list of `k`-dimensional F₂ subspaces (sorted element vectors) contained
in `S`, return every distinct `(k+1)`-dimensional subspace contained in `S`,
formed as `M ∪ (M ⊕ x)` for `x ∈ S ∖ M` whose coset `M ⊕ x` is entirely in `S`.
"""
function expand_subspaces(S::AbstractVector{<:Integer}, subspaces::Vector{Vector{Int}},
                          n::Integer)
    isempty(subspaces) && return Vector{Int}[]
    inset = _set_mask(S, n)
    seen = Set{Vector{Int}}()
    out = Vector{Int}[]
    for M in subspaces
        Mset = Set(M)
        for s in S
            x = Int(s)
            x in Mset && continue
            coset = [m ⊻ x for m in M]
            all(e -> inset[e + 1], coset) || continue
            new = sort!(vcat(M, coset))
            if !(new in seen)
                push!(seen, new)
                push!(out, new)
            end
        end
    end
    out
end

"""
    subspace_count_signature(S, n) -> Vector{Int}

`[|S∖{0}|, #2-dim, #3-dim, …, 0]` — the count of F₂ subspaces of each dimension
whose nonzero elements lie in `S` (terminating in a `0`). A linear-equivalence
invariant of the set `S` (a linear bijection of `GF(2ⁿ)` maps subspaces-in-`S`
bijectively onto subspaces-in-`L(S)`). Backs `nonbent_signature` and
`image_subspaces`.
"""
function subspace_count_signature(S::AbstractVector{<:Integer}, n::Integer)
    counts = Int[length(S) - 1]
    cur = find_2d_subspaces(S, n)
    push!(counts, length(cur))
    while true
        cur = expand_subspaces(S, cur, n)
        push!(counts, length(cur))
        isempty(cur) && break
    end
    counts
end
