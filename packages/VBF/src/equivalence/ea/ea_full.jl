"""
Full enumeration of EA-equivalences.

[`ea_equivalence_certificate`](@ref) returns the *first* witnessing
triple `(L₁, A₂, A_drift)`; this file's [`ea_equivalences`](@ref)
returns *all* of them found by the Heggebakk search. Following Heggebakk's
"find all outer L₁ first, then for each try to find an inner permutation": the
enumeration ranges over every outer `L₁` (across every bucket map) and every
constant shift, recording one inner `A₂` per `(L₁, shift)` that admits one.
"""

"""
    ea_equivalences(F::SBox{N,T}, G::SBox{N,T}; k = 4,
                    max_outer_per_sigma = 10^6)
        -> Vector{@NamedTuple{L1, A2, A_drift}}

Every EA-equivalence certificate found by the heggebakk search:
named tuples `(L1::F2LinearMap, A2::F2LinearMap, A_drift::SBox)` with

    G(x) == L1(F(A2(x))) ⊕ A_drift(x)   for all x.

Empty if `F` and `G` are not EA-equivalent. Inherits the
degenerate-partition limitation (monomial APN with signature
`[2ⁿ-1, 1]` short-circuits via `max_outer_per_sigma`).

One inner `A₂` is recorded per `(outer L₁, constant shift)` pair (the
`eaFull` semantics); the result enumerates the distinct outer maps
rather than the full inner-automorphism orbit.
"""
function ea_equivalences(
    F::SBox{N,T},
    G::SBox;
    k::Int = 4,
    max_outer_per_sigma::Int = 10^6,
) where {N,T}
    results = NamedTuple{
        (:L1, :A2, :A_drift),
        Tuple{F2LinearMap{N,T},F2LinearMap{N,T},SBox{N,T}},
    }[]
    inputbits(F) == inputbits(G) || return results
    storage_type(F) == storage_type(G) || return results
    G::SBox{N,T}
    (is_permutation(F) && is_permutation(G)) || return results

    n_size = 1 << N
    partF = ea_partition(F, k)
    partG = ea_partition(G, k)
    sort(partF.bucket_sizes) == sort(partG.bucket_sizes) || return results
    sigmas = enumerate_bucket_maps(partF, partG)
    isempty(sigmas) && return results

    for sigma in sigmas
        outers = outer_permutations(partF, partG, sigma, T)
        length(outers) > max_outer_per_sigma && continue
        for L1_lut in outers
            L1_cols = T[L1_lut[(1<<i)+1] for i = 0:(N-1)]
            L1_map = F2LinearMap{N,T}(L1_cols)
            is_invertible(L1_map) || continue
            L1_inv = inv(L1_map)
            currentG_lut = T[L1_inv(G.lut[x+1]) for x = 0:(n_size-1)]
            for shift_val = 0:(n_size-1)
                shift = T(shift_val)
                shifted_lut = T[currentG_lut[x+1] ⊻ shift for x = 0:(n_size-1)]
                shifted_G = SBox{N,T}(shifted_lut)
                res = inner_permutation(F, shifted_G)
                res === nothing && continue
                A2_map = F2LinearMap{N,T}(T[res.A2[(1<<i)+1] for i = 0:(N-1)])
                A_drift_lut =
                    T[L1_map(shift ⊻ res.A_drift[x+1]) for x = 0:(n_size-1)]
                push!(
                    results,
                    (
                        L1 = L1_map,
                        A2 = A2_map,
                        A_drift = SBox{N,T}(A_drift_lut),
                    ),
                )
            end
        end
    end
    return results
end
