"""
Multiplicity-based partition used by heggebakk's EA-equivalence test.

For an SBox `F : F₂ⁿ → F₂ⁿ` and even integer `k ≥ 4`, define

    μ_F^k(v) := #{ (y₁, …, y_{k-1}) ∈ (F₂ⁿ)^{k-1} :
                  F(y₁) ⊕ ⋯ ⊕ F(y_{k-1}) ⊕ F(y₁ ⊕ ⋯ ⊕ y_{k-1}) = v }.

The **EA-partition of F at level k** groups elements `v ∈ F₂ⁿ` by their
`μ_F^k`-multiplicity. Two values are in the same bucket iff their
multiplicities agree.

Crucially the bucket-size multiset is an **EA-equivalence invariant**:
if `G(x) = L₁(F(L₂(x) ⊕ a)) ⊕ A_drift(x)` with `L₁, L₂` invertible
F₂-linear and `A_drift` arbitrary affine, then `μ_G^k(v) = μ_F^k(L₁^{-1}(v))`.
In particular the bucket-size multiset of `G` equals that of `F`, and
`L₁` must permute F's buckets onto G's buckets respecting sizes —
heggebakk's algorithm uses this to dramatically prune the search for
`L₁`. (This is sometimes called the "structure" of F in the
heggebakk-Berinde-Lupanov line of work.)

The default `k = 4` matches heggebakk's reference C implementation.
Higher even `k` yields finer partitions at exponentially higher cost
(`O(2^{n(k-1)})`).
"""

"""
    EAPartition

The bucket structure of `ea_partition(F, k)`. Fields:

- `n`              — input bit-width of `F`.
- `k`              — level used to compute the partition.
- `buckets`        — `buckets[i]` is the list of values whose
                     multiplicity matches `bucket_multiplicities[i]`.
- `bucket_sizes`   — `length(buckets[i])` for each `i`.
- `bucket_multiplicities` — `μ_F^k` of any element in `buckets[i]`.
- `position_of_value` — `position_of_value[v + 1]` is the bucket index
                     containing the value `v`.

Two `EAPartition`s share the **same bucket-size multiset** iff their
sorted `bucket_sizes` vectors are equal. This is the primary EA-
invariant comparison.
"""
struct EAPartition
    n::Int
    k::Int
    buckets::Vector{Vector{Int}}
    bucket_sizes::Vector{Int}
    bucket_multiplicities::Vector{Int}
    position_of_value::Vector{Int}
end

inputbits(p::EAPartition) = p.n
nbuckets(p::EAPartition) = length(p.buckets)

function Base.show(io::IO, p::EAPartition)
    print(io, "EAPartition(n=", p.n, ", k=", p.k,
          ", nbuckets=", nbuckets(p),
          ", sizes=", sort(p.bucket_sizes; rev = true), ")")
end

# ---------------------------------------------------------------------------
# Multiplicity computation.
# ---------------------------------------------------------------------------

# Recursive enumeration of (y₁, …, y_{k-1}) ∈ (F₂ⁿ)^{k-1} accumulating
# the running XOR `x = y₁ ⊕ … ⊕ y_i` of inputs and `v = F(y₁) ⊕ … ⊕ F(y_i)`
# of outputs. At depth k-1 we tabulate `v ⊕ F(x)`.
function _ea_mult_recurse!(
    multiplicities::Vector{Int},
    lut::Vector{T},
    n::Int, k::Int, i::Int, x::Int, v::Int,
) where {T}
    if i == k - 1
        @inbounds multiplicities[(v ⊻ Int(lut[x + 1])) + 1] += 1
        return
    end
    @inbounds for y in 0:(n - 1)
        _ea_mult_recurse!(multiplicities, lut, n, k,
                          i + 1, x ⊻ y, v ⊻ Int(lut[y + 1]))
    end
end

"""
    ea_multiplicities(F::SBox{N,T}, k::Int = 4) -> Vector{Int}

Compute `μ_F^k(v)` for every `v ∈ 0:2ⁿ-1`. Length `2ⁿ`; entry `v+1` is
`μ_F^k(v)`. `k` must be even and at least `4`.

Internal-but-exported (useful as a CCZ/EA invariant check).
"""
function ea_multiplicities(F::SBox{N,T}, k::Int = 4) where {N,T}
    (iseven(k) && k ≥ 4) ||
        throw(ArgumentError("ea_multiplicities: k must be even and ≥ 4, got k = $k"))
    n = 1 << N
    multiplicities = zeros(Int, n)
    _ea_mult_recurse!(multiplicities, Vector{T}(F.lut), n, k, 0, 0, 0)
    return multiplicities
end

# ---------------------------------------------------------------------------
# Partition construction.
# ---------------------------------------------------------------------------

"""
    ea_partition(F::SBox{N,T}, k::Int = 4) -> EAPartition

Construct the EA-multiplicity partition of `F` at level `k`. `k` must be
even and `≥ 4`; the default `k = 4` matches Heggebakk's algorithm.

# Complexity

`O(2^{n·(k-1)})` time. For `k = 4` and `n ≤ 8` this is fast (`≤ 2^{24}`
operations); for `n = 10, k = 4` it is `2^{30}` and takes seconds; for
`n = 12, k = 4` it is `2^{36}` and is best done on dedicated hardware.

# Examples

```jldoctest
julia> using VBF

julia> p = ea_partition(load_apn_function("n5_Gold_x3"));

julia> p isa VBF.EAPartition
true

julia> nbuckets(p) ≥ 1
true
```
"""
function ea_partition(F::SBox{N,T}, k::Int = 4) where {N,T}
    n = 1 << N
    multiplicities = ea_multiplicities(F, k)

    bucket_of_mult = Dict{Int, Int}()
    buckets = Vector{Vector{Int}}()
    bucket_multiplicities = Int[]
    position_of_value = Vector{Int}(undef, n)

    @inbounds for v in 0:(n - 1)
        m = multiplicities[v + 1]
        idx = get(bucket_of_mult, m, 0)
        if idx == 0
            push!(buckets, Int[])
            push!(bucket_multiplicities, m)
            idx = length(buckets)
            bucket_of_mult[m] = idx
        end
        push!(buckets[idx], v)
        position_of_value[v + 1] = idx
    end

    bucket_sizes = [length(b) for b in buckets]
    return EAPartition(N, k, buckets, bucket_sizes, bucket_multiplicities, position_of_value)
end

"""
    ea_partition_signature(F::SBox{N,T}, k::Int = 4) -> Vector{Int}

The **EA-invariant signature** of `F`: the sorted-descending bucket-size
multiset of `ea_partition(F, k)`. Two EA-equivalent SBoxes have equal
signatures; the converse does not hold (signature equality is a fast
necessary condition for EA-equivalence, used by heggebakk's algorithm
to short-circuit before the heavy search).
"""
function ea_partition_signature(F::SBox{N,T}, k::Int = 4) where {N,T}
    sort!(copy(ea_partition(F, k).bucket_sizes); rev = true)
end
