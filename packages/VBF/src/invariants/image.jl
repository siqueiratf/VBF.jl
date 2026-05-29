"""
Image-set structure invariants.

The image (set of attained output values) of `F`, and the per-dimension counts of
the F₂ subspaces it contains. Under `F ↦ L₁ ∘ F ∘ L₂` the image becomes
`L₁(image)`, a linear bijection of it, so both are linear-equivalence invariants
(the latter discriminating; cf. Kaleyski's VBF library).
"""

"""
    image_set(F) -> Vector{Int}

The sorted set of distinct output values of `F` (no multiplicities). For a
permutation this is all of `GF(2ⁿ)`.
"""
image_set(F::SBox{N, T}) where {N, T} = sort!(collect(Set(Int.(F.lut))))

"""
    image_subspaces(F) -> Vector{Int}

[`subspace_count_signature`](@ref) of `image_set(F)` — `[#image∖{0}, #2-dim,
#3-dim, …]`. A linear-equivalence invariant (trivial for permutations, whose
image is the whole space).
"""
image_subspaces(F::SBox{N, T}) where {N, T} = subspace_count_signature(image_set(F), N)
