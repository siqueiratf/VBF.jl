"""
Algebraic-degree primitives.

The **algebraic degree** of a vectorial Boolean function `F : F₂ᴺ → F₂ᴺ`
is the maximum Hamming weight of any monomial appearing in the ANF of
any output coordinate. The **degree spectrum** is the multiset of
per-coordinate degrees.

# Public surface
- [`algebraic_degree`](@ref) — single integer.
- [`degree_spectrum`](@ref)  — per-output-bit degree histogram.
"""

"""
    algebraic_degree(s::SBox) -> Int

Maximum Hamming weight of any monomial appearing in the ANF of any
output coordinate of `s`.

# Examples
```jldoctest
julia> using VBF

julia> algebraic_degree(load_literature_sbox("AES"))
7

julia> algebraic_degree(load_literature_sbox("PRESENT"))
3
```
"""
function algebraic_degree(s::SBox{N, T}) where {N, T}
    a = anf(s)
    deg = 0
    @inbounds for m in 0:length(a) - 1
        a[m + 1] == zero(T) && continue
        w = count_ones(UInt(m))
        w > deg && (deg = w)
    end
    deg
end

"""
    degree_spectrum(s::SBox) -> Spectrum

Histogram of per-output-coordinate algebraic degrees. Each of the `N`
output coordinates contributes one entry. For a function whose every
coordinate has degree `d`, the spectrum is `{d => N}`.
"""
function degree_spectrum(s::SBox{N, T}) where {N, T}
    a = anf(s)
    sp = Spectrum()
    @inbounds for b in 0:N - 1
        mask = T(1) << b
        deg_b = 0
        for m in 0:length(a) - 1
            (a[m + 1] & mask) == zero(T) && continue
            w = count_ones(UInt(m))
            w > deg_b && (deg_b = w)
        end
        add!(sp, deg_b)
    end
    sp
end
