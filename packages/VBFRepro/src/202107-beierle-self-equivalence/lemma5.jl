# Implements Lemma5 and Algorithm1 isSmallest, BBL2021.
# Pseudocode: validate commuting permutations; compare only known common prefixes.
# VBF API used: F2LinearMap, rank_f2.

include("helpers.jl")
using VBF: F2LinearMap, rank_f2

"""Validate the supplied Lemma5 subsets; arbitrary nonlinear permutations are rejected."""
function validated_commutant_luts(subset, M, n)
    m = linear_map_lut(M,n)
    result = Vector{Int}[]
    for C in subset
        lut = C isa F2LinearMap ? Int[C(x) for x in 0:(1<<n)-1] : linear_map_lut(C,n)
        sort(lut) == collect(0:(1<<n)-1) || throw(ArgumentError("commutant member must be invertible"))
        lut[1] == 0 && all(lut[x+1] == xor(lut[(x & -x)+1], lut[(x & (x-1))+1]) for x in 1:(1<<n)-1) ||
            throw(ArgumentError("commutant member must be linear"))
        all(lut[m[x+1]+1] == m[lut[x+1]+1] for x in 0:(1<<n)-1) ||
            throw(ArgumentError("supplied map does not commute"))
        push!(result,lut)
    end
    unique(result)
end

"""Only use transformations stabilizing the initial partial LUT and its domain."""
function seed_stabilizing_transformations(input_luts, output_luts, seed)
    pairs = Tuple{Vector{Int},Vector{Int}}[]
    for ci in input_luts, co in output_luts
        all((seed[x] == -1) == (seed[ci[x]+1] == -1) &&
            (seed[x] == -1 || co[seed[ci[x]+1]+1] == seed[x]) for x in eachindex(seed)) || continue
        push!(pairs,(ci,co))
    end
    pairs
end

"""
Reject only if a fully known shared prefix proves C_B∘F∘C_A lexicographically
smaller. Unknown entries break comparison; assigning a sentinel an ordering
would unsoundly discard branches with different assigned domains.
"""
function isSmallest(sbox, transformations)
    for (ci,co) in transformations
        for x in eachindex(sbox)
            y = sbox[x]
            z = sbox[ci[x]+1]
            (y == -1 || z == -1) && break
            z = co[z+1]
            z < y && return false
            z > y && break
        end
    end
    true
end
