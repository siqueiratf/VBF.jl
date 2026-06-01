"""
The Π_F multiset (after Kaleyski's VBF library, `pif_single_beta`).

For a fixed shift `β`, consider the shifted derivatives
`D_a^β F(x) = F(x) ⊕ F(x⊕a) ⊕ F(a⊕β)`. For each output `b`, count the number of
directions `a` for which some `x` gives `D_a^β F(x) = b`; the multiset of those
counts (over all `b`) is `Π_F(β)`. Collected over all `β` it is a
linear-equivalence invariant of `F`.
"""

"""
    pi_multiset(F, β) -> Spectrum

`Π_F(β)`: a histogram mapping *(number of derivative directions hitting an
output)* → *(how many outputs have that count)*, for the shifted derivatives
`F(x) ⊕ F(x⊕a) ⊕ F(a⊕β)`. The counts run over the `2ⁿ` output values, so the
total mass equals `2ⁿ`.

# Examples
```jldoctest
julia> using VBF

julia> total_mass(pi_multiset(gold_apn(5, 1), 0)) == 1 << 5
true
```
"""
function pi_multiset(F::SBox{N,T}, β::Integer) where {N,T}
    n = 1 << N
    lut = F.lut
    b0 = Int(β)
    hits = zeros(Int, n)  # hits[b+1] = #directions a that reach b
    seen = falses(n)
    @inbounds for a = 0:(n-1)
        fill!(seen, false)
        fab = Int(lut[(a⊻b0)+1])     # F(a⊕β)
        for x = 0:(n-1)
            b = (Int(lut[x+1]) ⊻ Int(lut[(x⊻a)+1])) ⊻ fab
            seen[b+1] = true
        end
        for b = 0:(n-1)
            seen[b+1] && (hits[b+1] += 1)
        end
    end
    sp = Spectrum()
    counts = zeros(Int, n + 1)  # counts[m+1] = #outputs hit by m directions
    for h in hits
        counts[h+1] += 1
    end
    for m = 0:n
        counts[m+1] > 0 && add!(sp, m, counts[m+1])
    end
    sp
end
