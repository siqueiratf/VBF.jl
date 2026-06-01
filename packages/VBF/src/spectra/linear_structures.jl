"""
Linear structures of a vectorial Boolean function.

A **linear structure** of `F : F₂ᴺ → F₂ᴺ` is a pair `(a, c)` with
`a ≠ 0` such that
``F(x ⊕ a) ⊕ F(x) = c`` for *every* `x ∈ F₂ᴺ`.

Such a pair manifests directly in the DDT as an entry of value `2^N` in
row `a` outside row 0; this module is therefore a thin reading lens
over [`ddt`](@ref).

A cryptographically strong S-box has *no* non-trivial linear structures.
Identity and affine functions, by contrast, have a full `2^N - 1`
non-trivial linear structures.

# Public surface
- [`linear_structures`](@ref) — list every `(a, c)` linear structure with `a ≠ 0`.
- [`has_linear_structure`](@ref) — Boolean shortcut.
"""

"""
    linear_structures(s::SBox{N, T}) -> Vector{Tuple{T, T}}

Every non-trivial linear structure `(a, c)` of `s`, sorted by `a` then `c`.
"""
function linear_structures(s::SBox{N,T}) where {N,T}
    n = 1 << N
    d = ddt(s)
    out = Tuple{T,T}[]
    @inbounds for a = 1:(n-1), c = 0:(n-1)
        d[a+1, c+1] == n && push!(out, (T(a), T(c)))
    end
    out
end

"""
    has_linear_structure(s::SBox) -> Bool

`true` iff `s` has at least one non-trivial linear structure.
"""
has_linear_structure(s::SBox) = !isempty(linear_structures(s))
