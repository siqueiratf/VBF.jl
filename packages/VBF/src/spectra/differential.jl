"""
Differential cryptanalysis primitives.

For an S-box `F : F₂ᴺ → F₂ᴺ`, the **Differential Distribution Table**
(DDT) records, for each input difference `a` and output difference `b`,
how many inputs `x` map a `⊕ a` shift to a `⊕ b` shift:

``DDT[a, b] = \\#\\{ x : F(x ⊕ a) ⊕ F(x) = b \\}``.

The **differential uniformity** is the largest entry of the DDT outside
row/column `a = b = 0` and bounds the success probability of any
single-round differential attack. A function whose differential
uniformity equals `2` (the minimum for even `N`) is called *almost
perfect nonlinear* (APN); the notion is due to
[Nyberg (1994)](@cite Nyberg_199400).

# Public surface
- [`ddt`](@ref) — the table.
- [`differential_spectrum`](@ref) — histogram of DDT entries (excluding
  the trivial row `a = 0`).
- [`differential_uniformity`](@ref) — the maximum entry of the DDT
  outside `(0, 0)`.
"""

"""
    ddt(s::SBox{N, T}) -> Matrix{Int}

Differential Distribution Table of `s`, sized `2^N × 2^N`.
`ddt(s)[a + 1, b + 1] = #{ x : F(x ⊕ a) ⊕ F(x) = b }` for
`a, b ∈ 0:2^N - 1`.

Invariants (checked in the property tests):
- Each row sums to `2^N`.
- Every entry is even for `N ≥ 2`.
- Row `0` is `[2^N, 0, 0, …, 0]` (the trivial difference).
- `ddt(s)[1, 1] = 2^N` because `a = b = 0`.
"""
function ddt(s::SBox{N,T}) where {N,T}
    n = 1 << N
    d = zeros(Int, n, n)
    lut = s.lut
    @inbounds for x = 0:(n-1)
        Fx = lut[x+1]
        for a = 0:(n-1)
            Fxa = lut[(x⊻a)+1]
            d[a+1, Int(Fx⊻Fxa)+1] += 1
        end
    end
    d
end

"""
    differential_spectrum(s::SBox) -> Spectrum

Multiset of DDT entries excluding the trivial row `a = 0`. The most
common entry in the spectrum is `0`; the highest is the differential
uniformity.
"""
function differential_spectrum(s::SBox)
    d = ddt(s)
    n = size(d, 1)
    sp = Spectrum()
    @inbounds for a = 2:n, b = 1:n      # skip row a=0
        add!(sp, d[a, b])
    end
    sp
end

"""
    differential_uniformity(s::SBox) -> Int

Largest DDT entry outside row `0`: the smallest `δ` for which `s` is
*differentially δ-uniform*, i.e. for every non-zero input difference `a` and
every output difference `b` the equation `F(x ⊕ a) ⊕ F(x) = b` has at most
`δ` solutions `x`. The minimum `δ = 2` (for even `N`) characterises an APN
function.

Computed one input difference at a time, so it uses `O(2ᴺ)` memory instead of
materialising the full `2ᴺ × 2ᴺ` DDT — usable for large `N` where [`ddt`](@ref)
would exhaust memory.

# Examples
```jldoctest
julia> using VBF

julia> differential_uniformity(load_literature_sbox("AES"))
4

julia> differential_uniformity(load_literature_sbox("PRESENT"))
4

julia> differential_uniformity(load_literature_sbox("GIFT"))
6
```
"""
function differential_uniformity(s::SBox)
    lut = s.lut
    fieldsize = length(lut)
    counts = zeros(Int, fieldsize)
    u = 0
    @inbounds for a = 1:(fieldsize-1)
        fill!(counts, 0)
        for x = 0:(fieldsize-1)
            counts[(Int(lut[x+1]) ⊻ Int(lut[(x⊻a)+1]))+1] += 1
        end
        m = maximum(counts)
        m > u && (u = m)
    end
    u
end
