"""
The Walsh-zeroes set.

For `F : F₂ⁿ → F₂ⁿ`, the **Walsh zeroes** are the pairs `(a, b) ∈
F₂ⁿ × F₂ⁿ` at which the linear approximation table `LAT(F)` vanishes:

    Z(F) := {(a, b) ∈ F₂²ⁿ : LAT_F(a, b) = 0}.

`Z(F)` always contains `2ⁿ - 1` "trivial" zeroes from the column
`b = 0` (since `LAT_F(a, 0) = 2ⁿ · 1[a = 0] - 2ⁿ` collapses to 0 for
`a ≠ 0`). For a random function the size of `Z(F)` is close to `2^n`;
for APN functions it has rich structure exploited by the
Canteaut-Perrin CCZ theory
([Canteaut and Perrin, 2019](@cite Canteaut_201906)).

The CCZ-equivalence test of Canteaut-Perrin starts by enumerating the
**n-dimensional F₂-linear subspaces of `Z(F)`**: for every such
subspace `V`, the affine map `L` of `F₂²ⁿ` whose first half of
basis-images is a basis of `V` yields a CCZ-equivalent function. Each
distinct EA-class in F's CCZ-class is reached by at least one such `V`.

# Packing convention

Entries of `Z(F)` are packed as `2n`-bit integers `(a << N) | b` — `a`
in the high `N` bits, `b` in the low `N` bits. Note this is *reversed*
from the function-graph packing (`(x << N) | y` with `x` = input,
`y` = output).
"""

"""
    walsh_zeroes(F::SBox{N,T}) -> Vector{UInt32}

Return `Z(F)` packed as a sorted vector of `2n`-bit `UInt32` values
`(a << N) | b`. Each entry corresponds to a pair `(a, b)` with
`LAT(F)[a + 1, b + 1] == 0`.

# Examples

```jldoctest
julia> using VBF

julia> Z = walsh_zeroes(load_literature_sbox("PRESENT"));

julia> length(Z) ≥ 15
true
```
"""
function walsh_zeroes(F::SBox{N,T}) where {N,T}
    n_size = 1 << N
    L = lat(F)
    zeroes = UInt32[]
    sizehint!(zeroes, n_size * 2)
    @inbounds for a = 0:(n_size-1)
        for b = 0:(n_size-1)
            if L[a+1, b+1] == 0
                push!(zeroes, (UInt32(a) << N) | UInt32(b))
            end
        end
    end
    sort!(zeroes)
    return zeroes
end

"""
    walsh_zeroes_size(F::SBox) -> Int

The cardinality `|Z(F)|`. A CCZ-equivalence invariant.
"""
walsh_zeroes_size(F::SBox) = length(walsh_zeroes(F))
