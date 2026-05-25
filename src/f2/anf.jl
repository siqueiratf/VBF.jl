"""
Algebraic Normal Form (ANF) via the Möbius transform.

The Möbius transform converts a Boolean function's truth table into its
ANF coefficients (and vice-versa — over F₂ it is its own inverse). For
a vectorial function `F : F₂ᴺ → F₂ᴺ` stored as a length-`2^N`
`Vector{T}`, *all `N` output coordinates are transformed simultaneously*
because bitwise XOR on `T` is independent per bit. The cost is
`O(N · 2^N)` integer XORs — one pass over the table per input bit.

# Public surface
- [`mobius!`](@ref) — in-place transform on a packed-coordinate LUT.
- [`mobius`](@ref)  — allocating counterpart.
- [`anf`](@ref)     — convenience wrapper returning a fresh ANF table.
"""

"""
    mobius!(lut::Vector{T}) where {T<:Unsigned} -> lut

In-place forward Möbius transform. Over F₂ this is involutive:
`mobius!(mobius!(x)) == x` for any input. Equivalently, `anf(s)`
followed by `mobius!` recovers the LUT.

The length of `lut` must be a power of 2.
"""
function mobius!(lut::Vector{T}) where {T<:Unsigned}
    n_pow = length(lut)
    n_pow ≥ 1 || throw(ArgumentError("mobius!: empty input"))
    n = trailing_zeros(n_pow)
    1 << n == n_pow ||
        throw(ArgumentError("mobius!: length $n_pow is not a power of 2"))
    block = 1
    while block < n_pow
        step = 2 * block
        @inbounds for start in 0:step:n_pow - 1
            for i in 1:block
                lut[start + i + block] ⊻= lut[start + i]
            end
        end
        block = step
    end
    lut
end

"""
    mobius(lut::AbstractVector{<:Unsigned}) -> Vector

Allocating Möbius transform: returns a fresh vector, leaves the input
untouched.
"""
mobius(lut::AbstractVector{T}) where {T<:Unsigned} = mobius!(collect(lut))

"""
    anf(s::SBox{N,T}) where {N,T} -> Vector{T}

ANF coefficient table of `s`. Entry `m + 1` (for `m ∈ 0:2^N-1`) has
bit `b` set iff the monomial `∏_{i : bit i of m is 1} x_i` appears in
the ANF of the `b`-th output coordinate of `s`.

To recover the truth table from `anf(s)`, call `mobius!` on it
(the transform is its own inverse).
"""
anf(s::SBox{N, T}) where {N, T} = mobius(s.lut)
