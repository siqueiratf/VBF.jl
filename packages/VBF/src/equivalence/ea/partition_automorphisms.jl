"""
Partition-preserving linear automorphisms.

The set of invertible F₂-linear maps that fix a function's k-multiplicity
partition (and the size of that set) — a thin wrapper over the EA machinery:
the k-multiplicity partition then partition-preserving outer permutations with
the identity bucket map, i.e. [`ea_partition`](@ref) +
[`outer_permutations`](@ref).
"""

"""
    partition_automorphisms(F::SBox{N,T}, k::Int = 4) -> Vector{Vector{T}}

Every invertible F₂-linear map `L` (returned as its length-`2ⁿ` LUT)
that preserves `F`'s `k`-multiplicity partition: each bucket maps into
a bucket of the same size, under the identity bucket map. This is the
candidate automorphism set heggebakk's `automorphism` tool reports.

`length(partition_automorphisms(F, k))` is the "order" reported by the
`order` tool.
"""
function partition_automorphisms(F::SBox{N,T}, k::Int = 4) where {N,T}
    p = ea_partition(F, k)
    sigma = collect(1:nbuckets(p))      # identity bucket map
    return outer_permutations(p, p, sigma, T)
end

"""
    permutation_order(F::SBox{N,T}) -> Int

The multiplicative order of a permutation `F`: the least `k ≥ 1` with
`F^k = identity` (k-fold self-composition). Ports the cycle-closure
loop in `order.c`'s `findOrder`.
"""
function permutation_order(F::SBox{N,T}) where {N,T}
    is_permutation(F) ||
        throw(ArgumentError("permutation_order: F must be a permutation"))
    n_size = 1 << N
    id_lut = T[T(x) for x = 0:(n_size-1)]
    F.lut == id_lut && return 1
    cur = copy(F.lut)
    order = 1
    while cur != id_lut
        cur = T[F.lut[cur[x+1]+1] for x = 0:(n_size-1)]
        order += 1
    end
    return order
end
