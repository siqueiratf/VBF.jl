"""
F₂-affine map algebra: the operations on [`F2AffineMap`](@ref) needed by
the CCZ / TU-decomposition layer.

Provides the `F2AffineMap` factory functions used there:
`identity_affine_map`, `zero_affine_map`, `block_diagonal_affine_map`, the
`generating_affine_map` family, `affine_map_from_masks`,
`affine_map_from_range_and_image`, `swap_affine_map`.

For `A(x) = L(x) ⊕ c`:

- `inv(A)`         — `A⁻¹(y) = L⁻¹(y) ⊕ L⁻¹(c)`.
- `compose(A1,A2)` — `A1 ∘ A2`: linear part `L1∘L2`, constant `A1(c2)`.
- `transpose(A)`   — transpose of the (linear) matrix; errors if `c ≠ 0`.

!!! note "Square maps only"
    [`F2AffineMap`](@ref) is square (`N → N`). Every map that arises in
    the TU-decomposition of an `(n,n)`-function is square, so the square
    algebra suffices. Rectangular `N → M` maps would need a separate type.
"""

# --- canonical instances ------------------------------------------------------

"""
    identity_affine_map(N::Integer, T::Type{<:Unsigned}=_storage_for(N)) -> F2AffineMap

Identity affine map of dimension `N` (linear part identity, constant 0).
"""
identity_affine_map(N::Integer, T::Type{<:Unsigned}=_storage_for(N)) =
    F2AffineMap{N, T}(identity_linear_map(N, T), zero(T))

"""
    zero_affine_map(N::Integer, T::Type{<:Unsigned}=_storage_for(N)) -> F2AffineMap

Zero affine map of dimension `N` (linear part and constant both zero).
"""
zero_affine_map(N::Integer, T::Type{<:Unsigned}=_storage_for(N)) =
    F2AffineMap{N, T}(zero_linear_map(N, T), zero(T))

# --- inverse / compose / transpose --------------------------------------------

"""
    Base.inv(A::F2AffineMap{N, T}) -> F2AffineMap{N, T}

Compositional inverse: `A⁻¹(y) = L⁻¹(y ⊕ c) = L⁻¹(y) ⊕ L⁻¹(c)`, where
`L` is `A`'s linear part and `c` its constant. Throws if `L` is
singular.
"""
function Base.inv(A::F2AffineMap{N, T}) where {N, T}
    Linv = inv(A.linear)
    F2AffineMap{N, T}(Linv, Linv(A.constant))
end

"""
    compose(A1::F2AffineMap{N, T}, A2::F2AffineMap{N, T}) -> F2AffineMap{N, T}

`A1 ∘ A2`: the affine map `x ↦ A1(A2(x))`. Linear part `L1 ∘ L2`,
constant `A1(c2)`.
"""
compose(A1::F2AffineMap{N, T}, A2::F2AffineMap{N, T}) where {N, T} =
    F2AffineMap{N, T}(compose(A1.linear, A2.linear), A1(A2.constant))

Base.:∘(A1::F2AffineMap{N, T}, A2::F2AffineMap{N, T}) where {N, T} = compose(A1, A2)

"""
    Base.transpose(A::F2AffineMap{N, T}) -> F2AffineMap{N, T}

Transpose of the linear part (constant 0). Throws if `A` is non-linear.
"""
function Base.transpose(A::F2AffineMap{N, T}) where {N, T}
    is_linear(A) ||
        throw(ArgumentError("transpose(F2AffineMap): map must be linear (constant 0)"))
    F2AffineMap{N, T}(transpose(A.linear), zero(T))
end

# --- block-diagonal & swap ----------------------------------------------------

"""
    block_diagonal_affine_map(A::F2AffineMap, B::F2AffineMap) -> F2AffineMap

The block-diagonal map acting as `B` on the low `inputbits(B)` bits and
`A` on the high `inputbits(A)` bits (`x ∥ y ↦ B(x) ∥ A(y)` with `B`'s
output in the low bits). Note the first argument `A` occupies the *high*
coordinates.
"""
function block_diagonal_affine_map(A::F2AffineMap{Na, Ta},
                                   B::F2AffineMap{Nb, Tb}) where {Na, Ta, Nb, Tb}
    M = Na + Nb
    S = _storage_for(M)
    cols = Vector{S}(undef, M)
    @inbounds for i in 1:Nb
        cols[i] = S(B.linear.cols[i])
    end
    @inbounds for i in 1:Na
        cols[Nb + i] = S(A.linear.cols[i]) << Nb
    end
    cst = S(B.constant) | (S(A.constant) << Nb)
    F2AffineMap{M, S}(F2LinearMap{M, S}(cols), cst)
end

"""
    swap_affine_map(t::Integer, n::Integer, m::Integer) -> F2AffineMap

The `(n+m) → (n+m)` linear map that swaps a `TU`-decomposition's two
branches. The image vectors are, in
order: `2^(n+i)` for `i<t`, `2^(t+i)` for `i<n-t`, `2^i` for `i<t`, and
`2^(t+n+i)` for `i<m-t`.
"""
function swap_affine_map(t::Integer, n::Integer, m::Integer)
    M = n + m
    S = _storage_for(M)
    cols = S[]
    sizehint!(cols, M)
    for i in 0:t-1;     push!(cols, S(1) << (n + i));     end
    for i in 0:n-t-1;   push!(cols, S(1) << (t + i));     end
    for i in 0:t-1;     push!(cols, S(1) << i);           end
    for i in 0:m-t-1;   push!(cols, S(1) << (t + n + i)); end
    F2AffineMap{M, S}(F2LinearMap{M, S}(cols), zero(S))
end

# --- generating family --------------------------------------------------------

"""
    generating_affine_map(basis::AbstractVector{T}, N::Integer) -> F2AffineMap{N, T}

A bijective linear map whose first `length(basis)` columns are `basis`
and whose remaining columns complete it to a basis of F₂ᴺ (via
[`complete_basis`](@ref)): `L(2ⁱ) = basis[i]` for `i < length(basis)`.
Ports `generating_F2AffineMap`.
"""
function generating_affine_map(basis::AbstractVector{T}, N::Integer) where {T<:Unsigned}
    cols = complete_basis(basis, N)
    F2AffineMap{N, T}(F2LinearMap{N, T}(cols), zero(T))
end

"""
    generating_affine_map_r(basis::AbstractVector{T}, N::Integer) -> F2AffineMap{N, T}

The reversed counterpart of [`generating_affine_map`](@ref): `basis`
occupies the **high** columns and the completion (via
[`complete_basis_reversed`](@ref)) the low ones, so
`L(2^(N-length(basis)+i)) = basis[i]`. Ports `generating_F2AffineMap_r`.
"""
function generating_affine_map_r(basis::AbstractVector{T}, N::Integer) where {T<:Unsigned}
    cols = complete_basis_reversed(basis, N)
    F2AffineMap{N, T}(F2LinearMap{N, T}(cols), zero(T))
end

"""
    affine_map_from_masks(masks::AbstractVector{T}, N::Integer) -> F2AffineMap{N, T}

The (square) linear map with `L(2ⁱ) = masks[i]` for `i < length(masks)`
and `L(2ⁱ) = 0` otherwise. Ports the square case of
`F2AffineMap_from_masks`.
"""
function affine_map_from_masks(masks::AbstractVector{T}, N::Integer) where {T<:Unsigned}
    length(masks) ≤ N ||
        throw(ArgumentError("affine_map_from_masks: more masks ($(length(masks))) than columns (N=$N)"))
    cols = zeros(T, N)
    @inbounds for i in 1:length(masks)
        cols[i] = masks[i]
    end
    F2AffineMap{N, T}(F2LinearMap{N, T}(cols), zero(T))
end

"""
    affine_map_from_range_and_image(inputs::AbstractVector{T}, outputs::AbstractVector{T},
                                    N::Integer) -> F2AffineMap{N, T}

The (square) linear map sending `inputs[i] ↦ outputs[i]` for each `i`
(`inputs` must be linearly independent). Ports the square case of
`F2AffineMap_from_range_and_image`:
`affine_map_from_masks(outputs, N) ∘ inv(generating_affine_map(inputs, N))`.
"""
function affine_map_from_range_and_image(inputs::AbstractVector{T},
                                         outputs::AbstractVector{T},
                                         N::Integer) where {T<:Unsigned}
    compose(affine_map_from_masks(outputs, N), inv(generating_affine_map(inputs, N)))
end
