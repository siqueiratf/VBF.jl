using BFA
using Random

"""
    random_function_sbox(rng, ::Val{N})

A uniformly random `SBox{N}` (not necessarily a permutation), drawn from `rng`.
"""
function random_function_sbox(rng::AbstractRNG, ::Val{N}) where N
    n = 1 << N
    SBox{N}(rand(rng, 0:n - 1, n))
end

"""
    random_permutation_sbox(rng, ::Val{N})

A uniformly random permutation `SBox{N}`, drawn from `rng`.
"""
function random_permutation_sbox(rng::AbstractRNG, ::Val{N}) where N
    n = 1 << N
    lut = collect(0:n - 1)
    shuffle!(rng, lut)
    SBox{N}(lut)
end
