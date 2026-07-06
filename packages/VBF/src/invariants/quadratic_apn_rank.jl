"""
Rank-based APN test for quadratic functions.

For a **quadratic** `F : F₂ⁿ → F₂ⁿ` and any fixed `a ≠ 0`, the map

    B_a(x) := F(x ⊕ a) ⊕ F(x) ⊕ F(a) ⊕ F(0)

is **linear** in `x`, with `B_a(a) = 0`, so `rank(B_a) ≤ n - 1`. `F` is
APN iff `ker(B_a) = {0, a}`, i.e. iff `rank(B_a) = n - 1`, for every
`a ≠ 0`. Testing all `a` needs only `n` LUT lookups and one `n × n`
F₂ rank per `a` — `O(n²·2ⁿ)` word operations total versus `O(2^{2n})`
table entries for the DDT — and admits an early exit at the first
failing `a`, which makes it the screen of choice for large sweeps of
quadratic families (e.g. the bivariate constructions at `n ≥ 12`).
"""

"""
    is_quadratic_apn_rank(F::SBox{N}) -> Bool

Fast APN test for **quadratic** `F` via the Jacobian-rank criterion:
`true` iff `rank(B_a) = N - 1` for every `a ≠ 0`, where
`B_a(x) = F(x ⊕ a) ⊕ F(x) ⊕ F(a) ⊕ F(0)`.

For `F` of algebraic degree ≤ 2 this is equivalent to
`differential_uniformity(F) == 2`, at a fraction of the cost and with an
early exit on the first witness of non-APN-ness.

!!! warning
    The criterion is only meaningful when `F` is quadratic (each `B_a`
    linear). For higher-degree `F` the result is unrelated to APN-ness —
    this predicate does **not** check the degree. Use
    [`is_quadratic_apn`](@ref) when quadraticity is not known a priori.

# Examples

```jldoctest
julia> using VBF

julia> is_quadratic_apn_rank(gold_apn(8))
true

julia> is_quadratic_apn_rank(kim_apn())
true
```
"""
function is_quadratic_apn_rank(F::SBox{N,T}) where {N,T}
    n_size = 1 << N
    rows = Vector{T}(undef, N)
    f0 = F.lut[1]
    @inbounds for a = 1:(n_size-1)
        fa = F.lut[a+1] ⊻ f0
        for j = 0:(N-1)
            e = 1 << j
            rows[j+1] = F.lut[(e⊻a)+1] ⊻ F.lut[e+1] ⊻ fa
        end
        gauss_jordan!(rows; nbits = N) == N - 1 || return false
    end
    true
end
