"""
Linear cryptanalysis primitives.

For an S-box `F : F₂ᴺ → F₂ᴺ`, the **Linear Approximation Table** (LAT)
records the bias of every affine approximation of `F`:

``LAT[a, b] = ∑_{x ∈ F₂ᴺ} (-1)^{a · x + b · F(x)}``

where `a · x` is the F₂ inner product. The **linearity** of `F` is the
largest absolute value of any LAT entry outside `(0, 0)`; equivalently,
the input-output correlation that any non-trivial linear approximation
of `F` can achieve.

# Public surface
- [`lat`](@ref) — the table.
- [`absolute_walsh_spectrum`](@ref) — histogram of `|LAT[a, b]|`
  excluding the trivial `(0, 0)` entry.
- [`linearity`](@ref) — the maximum of `|LAT[a, b]|` outside `(0, 0)`.
"""

"""
    lat(s::SBox{N, T}) -> Matrix{Int}

Linear Approximation Table of `s`, sized `2^N × 2^N`.
Column `b + 1` is the Walsh-Hadamard spectrum of the Boolean component
`x ↦ b · F(x)`.

Invariants (checked in tests):
- `LAT[1, 1] = 2^N` (trivial `0 ≡ 0`).
- `LAT[a, 1] = 0` for `a ≠ 0` (any non-trivial input mask correlates
  with the zero output-mask only by chance, summing to 0).
- `LAT[1, b] = 0` for `b ≠ 0` *iff* `s` is balanced (every coordinate
  is balanced for a permutation).
- Per row (and per column), `∑_b LAT[a, b]^2 = 2^(2N)` by Parseval.
- Every entry is an even integer for `N ≥ 1`.
"""
function lat(s::SBox{N, T}) where {N, T}
    n = 1 << N
    L = zeros(Int, n, n)
    lut = s.lut
    @inbounds for b in 0:n - 1
        bT = T(b)
        v = Vector{Int}(undef, n)
        for x in 0:n - 1
            v[x + 1] = 1 - 2 * (count_ones(bT & lut[x + 1]) & 1)
        end
        walsh_hadamard!(v)
        for a in 0:n - 1
            L[a + 1, b + 1] = v[a + 1]
        end
    end
    L
end

"""
    absolute_walsh_spectrum(s::SBox) -> Spectrum

Histogram of `|LAT[a, b]|` over `(a, b) ≠ (0, 0)`. The peak of the
spectrum is the [`linearity`](@ref).
"""
function absolute_walsh_spectrum(s::SBox)
    L = lat(s)
    n = size(L, 1)
    sp = Spectrum()
    @inbounds for a in 1:n, b in 1:n
        a == 1 && b == 1 && continue
        add!(sp, abs(L[a, b]))
    end
    sp
end

"""
    linearity(s::SBox) -> Int

Maximum of `|LAT[a, b]|` over `(a, b) ≠ (0, 0)`. The smaller, the
better the resistance to single-round linear cryptanalysis. The
*nonlinearity* is `2^(N-1) - linearity / 2`.

# Examples
```jldoctest
julia> using VBF

julia> linearity(load_literature_sbox("AES"))
32

julia> linearity(load_literature_sbox("PRESENT"))
8
```
"""
function linearity(s::SBox)
    L = lat(s)
    n = size(L, 1)
    u = 0
    @inbounds for a in 1:n, b in 1:n
        a == 1 && b == 1 && continue
        v = abs(L[a, b])
        v > u && (u = v)
    end
    u
end

"""
    walsh_power_moment(s, k; shift_a=0, shift_b=0) -> Int

The (shifted) `k`-th Walsh power moment
`Σ_{a,b} (-1)^{a·shift_a ⊕ b·shift_b} · W_F(a,b)^k`, where `W_F(a,b)` is the LAT
entry. With `shift_a = shift_b = 0` this is the classical power moment;
`sigma_multiplicities` aggregates a related shifted family. (After
`vbf_wt_power_moment` in Kaleyski's VBF library.)
"""
function walsh_power_moment(s::SBox{N, T}, k::Integer;
                            shift_a::Integer = 0, shift_b::Integer = 0) where {N, T}
    L = lat(s)
    n = 1 << N
    sa = Int(shift_a); sb = Int(shift_b); kk = Int(k)
    total = 0
    @inbounds for a in 0:n - 1, b in 0:n - 1
        sgn = isodd(count_ones(a & sa) + count_ones(b & sb)) ? -1 : 1
        total += sgn * Int(L[a + 1, b + 1])^kk
    end
    total
end
