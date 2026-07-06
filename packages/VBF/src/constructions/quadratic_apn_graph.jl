"""
Ortho-derivative-based CCZ automorphisms and EA mappings (quadratic APN).

For a quadratic APN `F`, the linear-equivalence class of its
ortho-derivative `π_F` is an EA-invariant, and — more strongly — the
linear self-equivalences of `π_F` lift to CCZ-automorphisms of `F`'s
graph. This file provides `automorphisms_from_ortho_derivative`,
`ea_mappings_from_ortho_derivative`, and
`enumerate_ea_classes_apn_quadratic`, built from
`self_linear_equivalences` / `linear_equivalences` (applied to the
ortho-derivative) and the CCZ graph primitives
(`ccz_block_decomposition`, `ea_mapping`, `graph_image_by`,
`graph_xor_equivalence`).

The reconstruction of the candidate map `L` and the final
`graph_xor_equivalence` filter make the result robust to the exact
`(L₁, L₂)` ↔ `(L_A, L_B)` convention: only maps that genuinely fix (or
relate) the graph survive.

The linear (self-)equivalences of the ortho-derivative come from
`linear_equivalences` when both ortho-derivatives are permutations and
from [`linear_equivalences_general`](@ref) otherwise (non-bijective
ortho-derivatives — e.g. every quadratic APN in even dimension, whose
ortho-derivative is many-to-one). Earlier versions used the
permutation-only search unconditionally and silently returned an empty
automorphism list in the even-dimension case.
"""

# From the (L1, L2) ortho-derivative maps, enumerate CCZ maps G_src → G_dst.
function _ortho_derivative_maps(
    F_dst::SBox{N,T},
    F_src::SBox{N,T},
    o_dst::SBox{N,T},
    o_src::SBox{N,T},
) where {N,T}
    result = F2LinearMap{2N,UInt32}[]
    n_size = 1 << N
    G_dst = FunctionGraph(F_dst)
    G_src = FunctionGraph(F_src)
    s_dst = F_dst.lut
    s_src = F_src.lut

    # o_src = L1 ∘ o_dst ∘ L2; the permutation-only search is faster when it
    # applies, the general backtracking covers many-to-one ortho-derivatives.
    eqs =
        is_permutation(o_dst) && is_permutation(o_src) ?
        linear_equivalences(o_dst, o_src) :
        linear_equivalences_general(o_dst, o_src)
    for eq in eqs
        L_A = eq.L2
        L_B = eq.L1
        L_A_inv = inv(L_A)
        L_B_T = transpose(L_B)
        # s_src ∘ L_A_inv evaluated on the canonical basis (and 0).
        s_src_LAinv = T[s_src[L_A_inv(T(x))+1] for x = 0:(n_size-1)]
        @inbounds for delta = 0:(n_size-1)
            # s_src[L_A_inv(0)] = s_src[0]
            C0 = s_dst[delta+1] ⊻ L_B_T(s_src_LAinv[1])
            img = Vector{T}(undef, N)
            for i = 0:(N-1)
                ei = 1 << i
                img[i+1] = C0 ⊻ s_dst[(ei⊻delta)+1] ⊻ L_B_T(s_src_LAinv[ei+1])
            end
            L_C = F2LinearMap{N,T}(img)
            L = ea_mapping(L_A_inv, L_B_T, L_C)
            offs = graph_xor_equivalence(G_dst, graph_image_by(G_src, L))
            isempty(offs) || push!(result, L)
        end
    end
    return result
end

"""
    automorphisms_from_ortho_derivative(F::SBox{N,T}) -> Vector{F2LinearMap{2N, UInt32}}

The CCZ-automorphisms of `F`'s graph derived from the linear
self-equivalences of `π_F = ortho_derivative(F)`. Empty if `F` is not a
quadratic APN.
"""
function automorphisms_from_ortho_derivative(F::SBox{N,T}) where {N,T}
    o = ortho_derivative(F)
    o === nothing && return F2LinearMap{2N,UInt32}[]
    return _ortho_derivative_maps(F, F, o, o)
end

"""
    ea_mappings_from_ortho_derivative(F::SBox{N,T}, F_prime::SBox{N,T})
        -> Vector{F2LinearMap{2N, UInt32}}

Every CCZ-map `L` with `graph(F) = L(graph(F_prime)) ⊕ c` (constant `c`
not returned), derived from the linear equivalences of the
ortho-derivatives. Non-empty iff `F` and `F_prime` are EA-equivalent
(for quadratic APN).
"""
function ea_mappings_from_ortho_derivative(
    F::SBox{N,T},
    F_prime::SBox{N,T},
) where {N,T}
    o = ortho_derivative(F)
    o_prime = ortho_derivative(F_prime)
    (o === nothing || o_prime === nothing) && return F2LinearMap{2N,UInt32}[]
    return _ortho_derivative_maps(F, F_prime, o, o_prime)
end

"""
    enumerate_ea_classes_apn_quadratic(F::SBox{N,T}) -> Vector{SBox{N,T}}

One representative per EA-equivalence class among the quadratic members
of `F`'s CCZ-class. Enumerates the CCZ-class
([`enumerate_ccz_class`](@ref)), keeps the degree-2 members, and
deduplicates them with the fast ortho-derivative EA test
([`ea_mappings_from_ortho_derivative`](@ref) — two quadratic APN are
EA-equivalent iff it returns a non-empty set).

(Redundant Walsh-zero spaces could be pruned up-front via the
ortho-derivative automorphisms; this instead deduplicates after
enumeration, trading some extra work for a simpler, convention-robust
implementation.)
"""
function enumerate_ea_classes_apn_quadratic(F::SBox{N,T}) where {N,T}
    classes = SBox{N,T}[]
    for r in enumerate_ccz_class(F)
        algebraic_degree(r) == 2 || continue
        if !any(c -> !isempty(ea_mappings_from_ortho_derivative(r, c)), classes)
            push!(classes, r)
        end
    end
    return classes
end

# Full sorted point set of the span of a basis of packed 2n-bit points.
function _span_point_set(basis, ::Val{M}) where {M}
    pts = UInt32[0]
    for b in basis
        pts = vcat(pts, UInt32[p ⊻ UInt32(b) for p in pts])
    end
    return sort!(pts)
end

"""
    ea_class_orbits(F::SBox{N,T}) -> NamedTuple

**All** EA-classes inside the CCZ-class of a quadratic APN `F`, as
orbits of the `n`-dimensional Walsh-zero subspaces of `Γ_F` under the
CCZ-automorphism group of the graph (acting in the Walsh domain by
`transpose(inv(L))`). Returns

    (; bases, nspaces, nauts, orbits)

where `bases` are the subspace bases (`extract_linear_subspaces`
order, matching [`enumerate_ccz_class`](@ref)'s representative order),
`nauts` the number of validated graph automorphisms, and
`orbits::Vector{Vector{Int}}` the orbit partition — one orbit per
EA-class, quadratic or not.

Soundness: every merge comes from an automorphism validated with
`graph_xor_equivalence`, so `length(orbits)` is always an **upper
bound** on the number of EA-classes. Exactness rests on the
automorphism list being complete, which holds for quadratic APN because
every CCZ self-equivalence of the graph induces a linear
self-equivalence of the ortho-derivative
([Canteaut-Couvreur-Perrin 2022](@cite Canteaut_202205)); the lift
enumerates all of them (× all constant offsets). Empirically this
reproduces the full EA-class census of Calderini 2020 Table 1 (all 13
quadratic n=6 CCZ-classes, counts 3..92) exactly.

Cost: subspace extraction + `nauts × nspaces` subspace images; seconds
for n = 6.
"""
function ea_class_orbits(F::SBox{N,T}) where {N,T}
    Z = walsh_zeroes(F)
    bases = extract_linear_subspaces(Z, N; max_bits = 2N)
    nb = length(bases)
    auts = automorphisms_from_ortho_derivative(F)
    spans = [_span_point_set(b, Val(2N)) for b in bases]
    key = Dict{Vector{UInt32},Int}(s => i for (i, s) in enumerate(spans))
    parent = collect(1:nb)
    function find(i)
        while parent[i] != i
            parent[i] = parent[parent[i]]
            i = parent[i]
        end
        return i
    end
    for L in auts
        Dm = transpose(inv(L))
        for (i, s) in enumerate(spans)
            img = sort!(UInt32[UInt32(Dm(p)) for p in s])
            j = get(key, img, 0)
            j == 0 && continue    # cannot happen for validated automorphisms
            ri, rj = find(i), find(j)
            ri != rj && (parent[ri] = rj)
        end
    end
    orbits_d = Dict{Int,Vector{Int}}()
    for i = 1:nb
        push!(get!(orbits_d, find(i), Int[]), i)
    end
    return (; bases, nspaces = nb, nauts = length(auts), orbits = collect(values(orbits_d)))
end
