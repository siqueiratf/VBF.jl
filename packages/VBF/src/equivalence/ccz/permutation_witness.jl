"""
Exact search for a permutation in the CCZ-class of a function.

# Criterion

Let `Γ_F = {(x, F(x))}` and, for a linear `L` of `F₂²ⁿ`, `Γ_G = L(Γ_F)`.
Since `W_G(u) = W_F(Lᵀu)`, `G` is a function iff `Lᵀ(F₂ⁿ × 0) ⊆ Z_F` and a
permutation iff in addition `Lᵀ(0 × F₂ⁿ) ⊆ Z_F`. Hence the CCZ-class of `F`
contains a permutation iff `Z_F ∪ {0}` contains two `n`-dimensional subspaces
`V`, `W` with `V ∩ W = {0}` ([Canteaut and Perrin, 2019](@cite Canteaut_201906)). Here `Z_F = {(a,b) : W_F(a,b) = 0}` with `a` the input
mask and `b` the output mask.

# Projection bound (exact pruning)

Let `NB = {b ≠ 0 : W_F(a,b) = 0 for some a}`. Every component `b ∉ NB ∪ {0}`
has no Walsh zero (for a quadratic APN function in even `n` these are its bent
components). If `V ⊆ Z_F ∪ {0}` is a subspace, its output projection
`π(V) = {b : (a,b) ∈ V}` is a linear subspace of `NB ∪ {0}`. If `V ∩ W = {0}`
with `dim V = dim W = n`, then `V + W = F₂²ⁿ`, hence `π(V) + π(W) = F₂ⁿ` and
`dim π(V) + dim π(W) ≥ n`. Let `d` be the largest dimension of a subspace of
`NB ∪ {0}`. Then:

1. if `d < ⌈n/2⌉`, no complementary pair exists;
2. otherwise both members of every pair satisfy `dim π(·) ≥ m := n - d`, so
   `π(·)` is contained in `U = {0} ∪` the union of the `max(m,1)`-dimensional
   subspaces of `NB ∪ {0}` (a subspace of dimension `≥ k ≥ 1` is the union
   of its `k`-dimensional subspaces). Both `V` and `W` lie in
   `Z_F^U = {(a,b) ∈ Z_F : b ∈ U}`.

The search is therefore: (1) enumerate subspaces of `NB` (in `F₂ⁿ`);
(2) if needed, enumerate every `n`-dimensional subspace of `Z_F^U` with
[`extract_linear_subspaces`](@ref) (exhaustive canonical Gauss-Jordan
enumeration), keep those with `dim π ≥ m`, and test all pairs for
`V ∩ W = {0}` by rank. Nothing in the argument is specific to quadratic or
APN functions; for quadratic APN functions it is fast because `NB` is small.
"""

"""
    CCZPermutationSearch

Result of [`ccz_permutation_search`](@ref).

- `status`: `:witness` (a complementary pair was found), `:none` (exhaustive
  proof that none exists) or `:inconclusive` (a budget stopped the search).
- `certificate`: `:witness`, `:nonbent_dimension` (stage 1: `d < ⌈n/2⌉`),
  `:exhaustive_pairs` (stage 2 completed without a pair) or `:budget`.
- `witness`: `nothing` or `(V, W)`, Gauss-Jordan bases packed `(a << n) | b`
  as in [`walsh_zeroes`](@ref).
- `nonbent_count`: `|NB|`; `max_nonbent_subspace_dim`: `d`.
- `subspace_counts`: number of subspaces of `NB ∪ {0}` of each dimension
  `1:d`.
- `candidate_subspaces`: number of `n`-dim subspaces of `Z_F^U` with
  `dim π ≥ n - d` (stage 2 only).
- `complementary_pairs`: unordered complementary pairs counted (all of them
  when `count = true`; otherwise 0 or 1).
- `elapsed_seconds`.
"""
struct CCZPermutationSearch
    status::Symbol
    certificate::Symbol
    witness::Union{Nothing,Tuple{Vector{UInt32},Vector{UInt32}}}
    nonbent_count::Int
    max_nonbent_subspace_dim::Int
    subspace_counts::Vector{Int}
    candidate_subspaces::Int
    complementary_pairs::Int
    elapsed_seconds::Float64
end

_cczperm_proj_rank(basis, N) = rank_f2(UInt32[b & ((UInt32(1) << N) - UInt32(1)) for b in basis]; nbits = N)

"""
    ccz_permutation_search(F::SBox{N}; count=false, max_nodes=typemax(Int),
        timeout_seconds=Inf) -> CCZPermutationSearch

Decide whether the CCZ-class of `F` contains a permutation, by searching for
two complementary `N`-dimensional subspaces of the Walsh-zero set `Z_F`
(see the file docstring for the exact pruning argument). With `count = true`
every complementary unordered pair among the candidate subspaces is counted
instead of stopping at the first. `max_nodes`/`timeout_seconds` bound the
stage-2 subspace enumeration; on a budget hit the status is `:inconclusive`
and nothing is claimed.

```jldoctest
julia> using VBF

julia> ccz_permutation_search(kim_apn()).status
:witness

julia> ccz_permutation_search(gold_apn(6, 1)).status
:none
```
"""
function ccz_permutation_search(F::SBox{N}; count::Bool = false,
        max_nodes::Int = typemax(Int), timeout_seconds::Real = Inf) where {N}
    t0 = time_ns()
    el() = (time_ns() - t0) / 1.0e9
    mask = (UInt32(1) << N) - UInt32(1)
    Z = walsh_zeroes(F)
    nbset = falses(1 << N)
    for z in Z
        b = z & mask
        b != 0 && (nbset[Int(b)+1] = true)
    end
    NB = UInt32[b for b in 1:((1<<N)-1) if nbset[b+1]]
    half = cld(N, 2)
    # Stage 1: subspaces of NB ∪ {0} of every dimension, giving d exactly.
    counts = Int[]
    d = 0
    for k in 1:N
        S = extract_linear_subspaces(NB, k; max_bits = N, algorithm = :optimized)
        isempty(S) && break
        push!(counts, length(S))
        d = k
    end
    if d < half
        return CCZPermutationSearch(:none, :nonbent_dimension, nothing, length(NB), d,
                                    counts, 0, 0, el())
    end
    m = N - d
    inU = falses(1 << N)
    inU[1] = true
    # A subspace of dimension ≥ k ≥ 1 is the union of its k-dim subspaces; for
    # m = 0 use k = 1 (the zero-dimensional projection is covered by b = 0).
    for B in extract_linear_subspaces(NB, max(m, 1); max_bits = N, algorithm = :optimized)
        for v in span_from_basis(B)
            inU[Int(v)+1] = true
        end
    end
    Zr = UInt32[z for z in Z if inU[Int(z & mask)+1]]
    # Stage 2: every N-dim subspace of Z_F^U, then the projection filter.
    out = extract_linear_subspaces_bounded(Zr, N; max_bits = 2N, max_nodes,
        timeout_seconds = max(0.0, Float64(timeout_seconds) - el()), algorithm = :optimized)
    if !is_exhausted(out)
        return CCZPermutationSearch(:inconclusive, :budget, nothing, length(NB), d,
                                    counts, 0, 0, el())
    end
    cands = Vector{UInt32}[]
    projs = Vector{UInt32}[]
    for B in search_solutions(out)
        _cczperm_proj_rank(B, N) >= m || continue
        push!(cands, B)
        push!(projs, UInt32[b & mask for b in B])
    end
    pairs_found = 0
    witness = nothing
    @inbounds for i in eachindex(cands), j in (i+1):length(cands)
        # Necessary: π(V) + π(W) = F₂ⁿ.
        rank_f2(UInt32[projs[i]; projs[j]]; nbits = N) == N || continue
        rank_f2(UInt32[cands[i]; cands[j]]; nbits = 2N) == 2N || continue
        pairs_found += 1
        witness === nothing && (witness = (copy(cands[i]), copy(cands[j])))
        count || break
    end
    if witness === nothing
        return CCZPermutationSearch(:none, :exhaustive_pairs, nothing, length(NB), d,
                                    counts, length(cands), 0, el())
    end
    return CCZPermutationSearch(:witness, :witness, witness, length(NB), d, counts,
                                length(cands), pairs_found, el())
end

"""
    ccz_permutation_witness(F::SBox) -> Union{Nothing, Tuple{Vector{UInt32},Vector{UInt32}}}

A complementary pair `(V, W)` of `n`-dimensional Walsh-zero subspaces of `F`
(packed bases), or `nothing` after an exhaustive proof that none exists. See
[`ccz_permutation_search`](@ref); [`ccz_permutation_from_witness`](@ref)
turns the pair into the permutation.
"""
function ccz_permutation_witness(F::SBox)
    r = ccz_permutation_search(F)
    r.status === :inconclusive && error("ccz_permutation_witness: search budget hit")
    return r.witness
end

"""
    ccz_permutation_from_witness(F::SBox{N,T}, V, W) -> SBox{N,T}

Build the function `G` with graph `L(Γ_F)`, where `L(g) = (v₁·g, …, vₙ·g,
w₁·g, …, wₙ·g)` for the packed bases `V = (vᵢ)`, `W = (wⱼ)` (so `Lᵀ` maps
`F₂ⁿ × 0` onto `V` and `0 × F₂ⁿ` onto `W`). It is computed directly from the
definition, independently of `F2LinearMap`: throws if `V ⊕ W ≠ F₂²ⁿ`, or if
the input coordinate of `L(Γ_F)` is not a bijection. When `V, W ⊆ Z_F` the
result is a permutation CCZ-equivalent to `F`; callers verify this.
"""
function ccz_permutation_from_witness(F::SBox{N,T}, V::AbstractVector{UInt32},
        W::AbstractVector{UInt32}) where {N,T}
    length(V) == N && length(W) == N || throw(ArgumentError("bases must have $N vectors"))
    rank_f2(UInt32[V; W]; nbits = 2N) == 2N || throw(ArgumentError("V ⊕ W ≠ F₂^$(2N)"))
    rows = UInt32[V; W]
    lut = Vector{T}(undef, 1 << N)
    seen = falses(1 << N)
    for x in 0:((1<<N)-1)
        g = (UInt32(x) << N) | UInt32(F.lut[x+1])
        nx = 0; ny = 0
        for i in 1:N
            nx |= (count_ones(rows[i] & g) & 1) << (i - 1)
            ny |= (count_ones(rows[N+i] & g) & 1) << (i - 1)
        end
        seen[nx+1] && throw(ArgumentError("L(Γ_F) is not the graph of a function"))
        seen[nx+1] = true
        lut[nx+1] = T(ny)
    end
    return SBox{N}(lut)
end
