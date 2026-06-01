"""
Sigma multiplicities — a Walsh-power-moment CCZ-invariant.

For `F : F₂ⁿ → F₂ⁿ` and an integer `k ≥ 2`, define

    σ_F^k(s) := 2^{-2n} · ∑_{a, b ∈ F₂ⁿ} (-1)^{b·s} · W_F(a, b)^k

where `W_F(a, b)` is the Walsh-Hadamard coefficient (the LAT entry).

The multiset of values `{σ_F^k(s) : s ∈ F₂ⁿ}` is a **CCZ-invariant**
(more discriminating than the LAT spectrum alone, and particularly
useful as a coarse filter between APN classes).

The double sum is reorganised so that `∑_a W_F(a, b)^k` is precomputed once per
`b`, dropping the cost from `O(2³ⁿ)` to `O(2²ⁿ)`.
"""

"""
    sigma_multiplicities(F::SBox{N,T}; k::Int = 4) -> Spectrum

The multiset `{σ_F^k(s) : s ∈ F₂ⁿ}` as a [`Spectrum`](@ref). The default
`k = 4` is the standard choice for the APN setting.

# Examples

```jldoctest
julia> using VBF

julia> sp = sigma_multiplicities(load_apn_function("n5_Gold_x3"));

julia> total_mass(sp) == (1 << 5)
true
```
"""
function sigma_multiplicities(F::SBox{N,T}; k::Int = 4) where {N,T}
    k ≥ 2 ||
        throw(ArgumentError("sigma_multiplicities: k must be ≥ 2, got k = $k"))
    n_size = 1 << N
    L = lat(F)
    # Precompute ∑_a W_F(a, b)^k per output mask b (Int128 for k = 4).
    rowsum = zeros(Int128, n_size)
    @inbounds for b = 0:(n_size-1)
        s_total = Int128(0)
        for a = 0:(n_size-1)
            w = Int128(L[a+1, b+1])
            pw = w
            for _ = 1:(k-1)
                pw *= w
            end
            s_total += pw
        end
        rowsum[b+1] = s_total
    end

    result = Spectrum()
    @inbounds for s = 0:(n_size-1)
        σ = Int128(0)
        for b = 0:(n_size-1)
            sign =
                ((count_ones(UInt(b) & UInt(s)) & 1) == 0) ? Int128(1) :
                Int128(-1)
            σ += sign * rowsum[b+1]
        end
        # Normalize by 2^(2N); the shift is exact for k ≥ 2.
        σ_norm = σ >> (2 * N)
        add!(result, Int(σ_norm))
    end
    return result
end
