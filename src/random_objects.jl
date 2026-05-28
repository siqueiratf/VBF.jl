"""
Random S-box and F₂-map generators (ports sboxU's `random_objects.py`).

All take an explicit `AbstractRNG` first (so tests reproduce with a
seeded generator) and dispatch on `Val{N}` for type stability; the
storage type `T` defaults to the smallest unsigned covering `N` bits.

- [`random_function_sbox`](@ref)        — uniform `SBox{N}` (any function)
- [`random_permutation_sbox`](@ref)      — uniform permutation `SBox{N}`
- [`random_linear_function`](@ref)       — `F2LinearMap{N}` (possibly singular)
- [`random_invertible_linear_map`](@ref) — random invertible `F2LinearMap{N}`
  (alias [`random_linear_permutation`](@ref), the sboxU name)
- [`random_affine_permutation`](@ref)    — invertible linear part + random shift
"""

using Random

@inline _nbit_mask(::Val{N}, ::Type{T}) where {N, T} =
    N == 8 * sizeof(T) ? ~zero(T) : T((one(T) << N) - one(T))

"""
    random_function_sbox(rng, ::Val{N}, ::Type{T}=_storage_for(N)) -> SBox{N,T}

A uniformly random `N`-bit S-box (not necessarily a permutation).
"""
function random_function_sbox(rng::AbstractRNG, ::Val{N},
                              ::Type{T} = _storage_for(N)) where {N, T}
    n = 1 << N
    SBox{N, T}(T[rand(rng, zero(T):T(n - 1)) for _ in 1:n])
end

"""
    random_permutation_sbox(rng, ::Val{N}, ::Type{T}=_storage_for(N)) -> SBox{N,T}

A uniformly random permutation `SBox{N}` (Fisher–Yates shuffle of the
identity LUT). Ports `rand_invertible_Sbox`.
"""
function random_permutation_sbox(rng::AbstractRNG, ::Val{N},
                                 ::Type{T} = _storage_for(N)) where {N, T}
    lut = collect(T(0):T((1 << N) - 1))
    shuffle!(rng, lut)
    SBox{N, T}(lut)
end

"""
    random_linear_function(rng, ::Val{N}, ::Type{T}=_storage_for(N)) -> F2LinearMap{N,T}

A random F₂-linear map (each basis image drawn uniformly; may be
singular). Ports the square case of `rand_linear_function`.
"""
function random_linear_function(rng::AbstractRNG, ::Val{N},
                                ::Type{T} = _storage_for(N)) where {N, T}
    mask = _nbit_mask(Val(N), T)
    F2LinearMap{N, T}(T[rand(rng, T) & mask for _ in 1:N])
end

"""
    random_invertible_linear_map(rng, ::Val{N}, ::Type{T}=_storage_for(N)) -> F2LinearMap{N,T}

A uniformly random *invertible* F₂-linear map: basis images are drawn
until `N` of them are linearly independent. Ports `rand_linear_permutation`.
"""
function random_invertible_linear_map(rng::AbstractRNG, ::Val{N},
                                      ::Type{T} = _storage_for(N)) where {N, T}
    mask = _nbit_mask(Val(N), T)
    cols = T[]
    bs = T[]
    while length(cols) < N
        v = rand(rng, T) & mask
        v == zero(T) && continue
        is_in_span(v, bs; nbits = N) && continue
        push!(cols, v)
        bs = linear_basis(vcat(bs, v); nbits = N)
    end
    F2LinearMap{N, T}(cols)
end

"""
    random_linear_permutation(rng, ::Val{N}, ::Type{T}=_storage_for(N))

Alias for [`random_invertible_linear_map`](@ref) (the sboxU name).
"""
const random_linear_permutation = random_invertible_linear_map

"""
    random_affine_permutation(rng, ::Val{N}, ::Type{T}=_storage_for(N)) -> F2AffineMap{N,T}

A random invertible F₂-affine map: an invertible linear part
([`random_invertible_linear_map`](@ref)) plus a uniformly random constant.
"""
function random_affine_permutation(rng::AbstractRNG, ::Val{N},
                                   ::Type{T} = _storage_for(N)) where {N, T}
    L = random_invertible_linear_map(rng, Val(N), T)
    F2AffineMap{N, T}(L, rand(rng, T) & _nbit_mask(Val(N), T))
end
