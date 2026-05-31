"""
Outer-permutation search for heggebakk-style EA-equivalence.

Given EA-partitions of `F` and `G`, this enumerates every invertible
F₂-linear map `L : F₂ⁿ → F₂ⁿ` such that `L` maps F's partition onto
G's partition in a **size-compatible** way:

    for all x ∈ F₂ⁿ, the F-bucket containing x and the G-bucket
    containing L(x) have the same size.

The set of such `L` is the candidate space for the outer linear map
`L₁` in an EA-equivalence `G(x) = L₁(F(A₂(x))) ⊕ A_drift(x)`.

# Pipeline

1. [`enumerate_bucket_maps`](@ref) — enumerate every size-preserving
   bijection `σ : F-buckets → G-buckets`. For partitions with all-
   distinct bucket sizes there is exactly one map; with `m` buckets of
   each repeated size the count multiplies by `m!`.
2. [`outer_permutations`](@ref) — for a fixed `σ`, DFS-enumerate every
   invertible linear `L` such that each F-bucket `i` maps into G-bucket
   `σ(i)`. Returned as LUT vectors.

The number of `L`'s is bounded by the partition refinement: it is
typically tiny (often `1` or a few dozen) since EA-invariance forces
heavy structure. heggebakk's algorithm iterates over these candidates
and for each invokes the inner-permutation search.
"""

# ---------------------------------------------------------------------------
# Bucket-map enumeration.
# ---------------------------------------------------------------------------

# Lightweight permutations generator: returns Vector{Vector{Int}} of all n!
# permutations of `v`. Used only for size-class permutations within bucket-
# map enumeration; the size classes are small in practice.
function _all_permutations(v::Vector{Int})
    n = length(v)
    n == 0 && return [Int[]]
    n == 1 && return [v]
    out = Vector{Vector{Int}}()
    n ≤ 20 && sizehint!(out, factorial(n))   # factorial(21) overflows Int64
    for i in 1:n
        rest = vcat(@view(v[1:(i - 1)]), @view(v[(i + 1):n]))
        for p in _all_permutations(rest)
            push!(out, [v[i]; p])
        end
    end
    return out
end

"""
    enumerate_bucket_maps(partF::EAPartition, partG::EAPartition;
                          max_maps = 10^6) -> Vector{Vector{Int}}

Every size-preserving bijection `σ : F-buckets → G-buckets`, returned as
a vector of `sigma` mappings each of length `nbuckets(partF)`. Entry
`sigma[i]` is the G-bucket index that F-bucket `i` maps to.

If the bucket-size multisets of `partF` and `partG` differ, returns an
empty vector (a fast necessary EA-equivalence rejection).

The number of maps is `∏ₛ mₛ!` where `mₛ` is the count of buckets of each
size `s`; for functions with many equal-size buckets (e.g. a generic
non-APN permutation) this explodes super-exponentially. To avoid
exhausting memory the enumeration **bails to an empty vector** when the
count would exceed `max_maps` — the caller then reports "not decided"
(`false`), consistent with Heggebakk's documented degeneration on
unstructured partitions. Quadratic APN do not hit this path (they route
through the ortho-derivative test).
"""
function enumerate_bucket_maps(partF::EAPartition, partG::EAPartition;
                               max_maps::Integer = 10^6)
    nF = nbuckets(partF)
    nbuckets(partG) == nF || return Vector{Vector{Int}}()
    # Group F-buckets and G-buckets by size
    f_by_size = Dict{Int, Vector{Int}}()
    g_by_size = Dict{Int, Vector{Int}}()
    @inbounds for (i, sz) in enumerate(partF.bucket_sizes)
        push!(get!(f_by_size, sz, Int[]), i)
    end
    @inbounds for (j, sz) in enumerate(partG.bucket_sizes)
        push!(get!(g_by_size, sz, Int[]), j)
    end
    # Size multiset must match exactly
    keys(f_by_size) == keys(g_by_size) || return Vector{Vector{Int}}()
    for sz in keys(f_by_size)
        length(f_by_size[sz]) == length(g_by_size[sz]) || return Vector{Vector{Int}}()
    end

    sorted_sizes = sort!(collect(keys(f_by_size)))
    # Bail before materializing if the map count ∏ₛ mₛ! would blow up. Uses
    # big-int arithmetic (factorial(21) already overflows Int64) and stops as
    # soon as the running product crosses the cap.
    total = big(1)
    for sz in sorted_sizes
        total *= factorial(big(length(g_by_size[sz])))
        total > max_maps && return Vector{Vector{Int}}()
    end
    # For each size, list of permutations of the G-buckets of that size
    perm_choices = [_all_permutations(g_by_size[sz]) for sz in sorted_sizes]

    # Cartesian product over the per-size permutations
    out = Vector{Vector{Int}}()
    sigma = zeros(Int, nF)
    function _recurse(level::Int)
        if level > length(sorted_sizes)
            push!(out, copy(sigma))
            return
        end
        sz = sorted_sizes[level]
        f_buckets = f_by_size[sz]
        for g_perm in perm_choices[level]
            @inbounds for (i, fb) in enumerate(f_buckets)
                sigma[fb] = g_perm[i]
            end
            _recurse(level + 1)
        end
    end
    _recurse(1)
    return out
end

# ---------------------------------------------------------------------------
# Outer-permutation DFS.
# ---------------------------------------------------------------------------

# DFS body. State threaded by mutable arrays; backtracking by undoing
# `generated_images` flags.
function _outer_recurse!(
    k::Int,
    basis::Vector{T},
    generated::Vector{T},
    generated_images::BitVector,
    partF::EAPartition,
    partG::EAPartition,
    sigma::Vector{Int},
    N::Int,
    results::Vector{Vector{T}},
) where {T<:Unsigned}
    if k == N
        push!(results, copy(generated))
        return
    end

    bk_F = partF.position_of_value[basis[k + 1] + 1]
    bk_G = sigma[bk_F]
    LIMIT = (k == 0) ? 1 : (1 << k)

    @inbounds for ck_val in partG.buckets[bk_G]
        ck = T(ck_val)
        # Must be a new image (L is a permutation)
        generated_images[ck + 1] && continue
        problem = false
        # Extend by linearity to all linear combinations of basis[0..k]
        for lincomb in 0:(LIMIT - 1)
            x = T(lincomb) ⊻ basis[k + 1]
            y = ck
            if k > 0
                for i in 0:(k - 1)
                    if ((lincomb >> i) & 1) == 1
                        y ⊻= generated[basis[i + 1] + 1]
                    end
                end
            end
            if partF.bucket_sizes[partF.position_of_value[x + 1]] !=
               partG.bucket_sizes[partG.position_of_value[y + 1]]
                problem = true
                break
            end
            generated[x + 1] = y
            generated_images[y + 1] = true
        end

        if !problem
            _outer_recurse!(k + 1, basis, generated, generated_images,
                            partF, partG, sigma, N, results)
        end

        # Reset generated_images for every y we (potentially) set.
        for lincomb in 0:(LIMIT - 1)
            y = ck
            if k > 0
                for i in 0:(k - 1)
                    if ((lincomb >> i) & 1) == 1
                        y ⊻= generated[basis[i + 1] + 1]
                    end
                end
            end
            generated_images[y + 1] = false
        end
    end
end

"""
    outer_permutations(partF::EAPartition, partG::EAPartition,
                       sigma::Vector{Int}, ::Type{T} = UInt8) -> Vector{Vector{T}}

Enumerate every invertible F₂-linear map `L` such that

    bucket_of(partF, x) == i  ⇒  bucket_of(partG, L(x)) == sigma[i]

for the bucket-map `sigma`. `L` is returned as its LUT: a length-`2ⁿ`
vector with `L(x) = result[x + 1]`.

The DFS guesses `L` on the standard basis `e_k = 2^k` and extends by
linearity at every step; backtracks as soon as any image lands in a
wrong-sized G-bucket.

`sigma` must come from [`enumerate_bucket_maps`](@ref) (no validation).
"""
function outer_permutations(
    partF::EAPartition,
    partG::EAPartition,
    sigma::Vector{Int},
    ::Type{T} = UInt8,
) where {T<:Unsigned}
    N = partF.n
    @assert partG.n == N
    @assert length(sigma) == nbuckets(partF)
    n = 1 << N
    results = Vector{Vector{T}}()
    generated = zeros(T, n)
    generated_images = falses(n)
    generated_images[1] = true   # L(0) = 0
    basis = T[T(1) << k for k in 0:(N - 1)]
    _outer_recurse!(0, basis, generated, generated_images,
                    partF, partG, sigma, N, results)
    return results
end

"""
    outer_permutations_all(F::SBox{N,T}, G::SBox{N,T}; k::Int = 4) ->
        (sigmas::Vector{Vector{Int}}, Ls_per_sigma::Vector{Vector{Vector{T}}})

Convenience: compute partitions of `F` and `G`, enumerate every bucket
map, and run `outer_permutations` for each. Returns the bucket maps in
parallel with their L-candidate LUT vectors.

If the bucket-size multisets of `F` and `G` differ, both returned
vectors are empty (a fast necessary EA-equivalence rejection).
"""
function outer_permutations_all(F::SBox{N,T}, G::SBox{N,T}; k::Int = 4) where {N,T}
    partF = ea_partition(F, k)
    partG = ea_partition(G, k)
    sigmas = enumerate_bucket_maps(partF, partG)
    Ls_per_sigma = [outer_permutations(partF, partG, σ, T) for σ in sigmas]
    return (sigmas = sigmas, Ls_per_sigma = Ls_per_sigma)
end
