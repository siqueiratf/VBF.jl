"""
Enumeration of *all* linear equivalences, and the self-equivalence groups.

[`are_linear_equivalent`](@ref) answers the yes/no question
"is `G = L₁ ∘ F ∘ L₂` for some invertible linear `L₁, L₂`?". Several
downstream tools (automorphism groups, ortho-derivative-based EA
mappings) need the *full set* of witnessing pairs `(L₁, L₂)`, not just
existence. This file provides that via a collect-all variant of the
propagation-pruned backtracking in `backtracking.jl`. It exposes
[`self_linear_equivalences`](@ref) and [`self_affine_equivalences`](@ref).
"""

# Rebuild (L₁, L₂) from the L₂ basis images; L₁ is forced by G = L₁ ∘ F ∘ L₂.
function _reconstruct_le_pair(
    F::SBox{N,T},
    G::SBox{N,T},
    l2_imgs::Vector{T},
) where {N,T}
    L2 = F2LinearMap{N,T}(copy(l2_imgs))
    n_pow = 1 << N
    lut_L1 = Vector{T}(undef, n_pow)
    @inbounds for x = 0:(n_pow-1)
        y = F.lut[L2(T(x))+1]      # F(L₂(x))
        lut_L1[y+1] = G.lut[x+1] # = G(x)
    end
    L1 = F2LinearMap{N,T}(T[lut_L1[(1<<j)+1] for j = 0:(N-1)])
    return (L1 = L1, L2 = L2)
end

"""
    linear_equivalences(F::SBox{N,T}, G::SBox{N,T}) -> Vector{@NamedTuple{L1, L2}}

Every pair `(L1, L2)` of invertible F₂-linear maps with
`G = L1 ∘ F ∘ L2`. Returns an empty vector if `F` and `G` are not
linearly equivalent (or either is not a permutation).

Collect-all variant of the backtracking search: identical
propagation/pruning, but instead of stopping at the first complete
`L₂` it records the reconstructed `(L1, L2)` pair and continues.
"""
function linear_equivalences(F::SBox{N,T}, G::SBox{N,T}) where {N,T}
    results = NamedTuple{(:L1, :L2),Tuple{F2LinearMap{N,T},F2LinearMap{N,T}}}[]
    (is_permutation(F) && is_permutation(G)) || return results
    n_pow = 1 << N

    phi_basis = Tuple{T,T}[]
    _phi_add!(phi_basis, T(F.lut[1]), T(G.lut[1])) || return results
    l2_imgs = T[]

    function recurse(i::Int)
        if i == N
            push!(results, _reconstruct_le_pair(F, G, l2_imgs))
            return
        end
        span = linear_basis(l2_imgs; nbits = N)
        @inbounds for c = T(1):T(n_pow-1)
            is_in_span(c, span; nbits = N) && continue
            push!(l2_imgs, c)
            phi_snap = length(phi_basis)
            ok = true
            n_old = 1 << i
            for x_old_idx = 0:(n_old-1)
                l2_x_old = zero(T)
                for k = 0:(i-1)
                    ((x_old_idx >> k) & 1) == 1 && (l2_x_old ⊻= l2_imgs[k+1])
                end
                x_new_idx = x_old_idx ⊻ (1 << i)
                a = T(F.lut[(l2_x_old⊻c)+1])
                A = T(G.lut[x_new_idx+1])
                if !_phi_add!(phi_basis, a, A)
                    ok = false
                    break
                end
            end
            ok && recurse(i + 1)
            resize!(phi_basis, phi_snap)
            pop!(l2_imgs)
        end
        return
    end

    recurse(0)
    return results
end

"""
    self_linear_equivalences(F::SBox) -> Vector{@NamedTuple{L1, L2}}

The **linear self-equivalence group** of `F`: every pair `(L1, L2)` of
invertible F₂-linear maps with `F = L1 ∘ F ∘ L2`. Always contains
`(identity, identity)`.

Equal to `linear_equivalences(F, F)`. Ports
`self_linear_equivalent_mappings`.
"""
self_linear_equivalences(F::SBox) = linear_equivalences(F, F)

"""
    self_affine_equivalences(F::SBox{N,T}) -> Vector{@NamedTuple{A1, A2}}

The **affine self-equivalence group** of `F`: every pair `(A1, A2)` of
invertible F₂-affine maps with `F = A1 ∘ F ∘ A2`. Ports
`self_affine_equivalent_mappings`.

# Algorithm

For each `(c_in, c_out) ∈ F₂ⁿ × F₂ⁿ`, the shifted function
`g(x) = F(x ⊕ c_in) ⊕ c_out` is linearly compared to `F`. Each linear
equivalence `g = L1 ∘ F ∘ L2` yields an affine self-equivalence with

    A1 = (linear = L1, constant = c_out),
    A2 = (linear = L2, constant = L2(c_in)),

since substitution gives `A1(F(A2(y))) = F(y)`. Cost is `O(2^{2n})`
linear-equivalence searches — affordable for `n ≤ 5`, expensive beyond.
"""
function self_affine_equivalences(F::SBox{N,T}) where {N,T}
    is_permutation(F) || throw(
        ArgumentError("self_affine_equivalences: F must be a permutation"),
    )
    n_pow = 1 << N
    results = NamedTuple{(:A1, :A2),Tuple{F2AffineMap{N,T},F2AffineMap{N,T}}}[]
    @inbounds for c_in = 0:(n_pow-1)
        for c_out = 0:(n_pow-1)
            shifted_lut =
                T[F.lut[(T(x)⊻T(c_in))+1] ⊻ T(c_out) for x = 0:(n_pow-1)]
            shifted = SBox{N,T}(shifted_lut)
            for eq in linear_equivalences(F, shifted)
                A1 = F2AffineMap(eq.L1, T(c_out))
                A2 = F2AffineMap(eq.L2, eq.L2(T(c_in)))
                push!(results, (A1 = A1, A2 = A2))
            end
        end
    end
    return results
end
