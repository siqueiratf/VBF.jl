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

!!! note "Permutation ortho-derivative required"
    These functions obtain the linear (self-)equivalences of the
    ortho-derivative via `linear_equivalences`, which is
    permutations-only. When the ortho-derivative is **not** a
    permutation (e.g. non-bijective quadratic APN such as `x³` over
    `GF(2⁴)`, whose ortho-derivative is many-to-one) the search yields
    an empty result. A LAT-based equivalence search would handle that
    case; implementing it (a separate algorithm) would lift this
    restriction.
"""

# Core: given the linear equivalences relating o_src and o_dst (as
# (L1, L2) pairs with o_dst = L1 ∘ o_src ∘ L2), enumerate candidate CCZ
# maps via the `delta` sweep and keep those that translate G_src to G_dst.
function _ortho_derivative_maps(
    F_dst::SBox{N,T}, F_src::SBox{N,T},
    o_dst::SBox{N,T}, o_src::SBox{N,T},
) where {N,T}
    result = F2LinearMap{2N, UInt32}[]
    n_size = 1 << N
    G_dst = FunctionGraph(F_dst)
    G_src = FunctionGraph(F_src)
    s_dst = F_dst.lut
    s_src = F_src.lut

    for eq in linear_equivalences(o_dst, o_src)   # o_src = L1 ∘ o_dst ∘ L2
        L_A = eq.L2
        L_B = eq.L1
        L_A_inv = inv(L_A)
        L_B_T = transpose(L_B)
        # s_src ∘ L_A_inv evaluated on the canonical basis (and 0).
        s_src_LAinv = T[s_src[L_A_inv(T(x)) + 1] for x in 0:(n_size - 1)]
        @inbounds for delta in 0:(n_size - 1)
            C0 = s_dst[delta + 1] ⊻ L_B_T(s_src_LAinv[1])   # s_src[L_A_inv(0)] = s_src[0]
            img = Vector{T}(undef, N)
            for i in 0:(N - 1)
                ei = 1 << i
                img[i + 1] = C0 ⊻ s_dst[(ei ⊻ delta) + 1] ⊻ L_B_T(s_src_LAinv[ei + 1])
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
    o === nothing && return F2LinearMap{2N, UInt32}[]
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
function ea_mappings_from_ortho_derivative(F::SBox{N,T}, F_prime::SBox{N,T}) where {N,T}
    o = ortho_derivative(F)
    o_prime = ortho_derivative(F_prime)
    (o === nothing || o_prime === nothing) && return F2LinearMap{2N, UInt32}[]
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
