"""
Bent-component analysis and the Gológlu nonbent signature.

A component function `F_b(x) = b·F(x)` is **bent** iff its Walsh spectrum is flat:
every coefficient `W_F(a,b)` has absolute value `2^{n/2}` (so `n` must be even).
The set of `b` whose component is *not* bent is a linear-equivalence invariant of
`F`; the **nonbent signature** (Gológlu) refines it into the per-dimension counts
of the F₂ subspaces it contains.
"""

"""
    bent_components(F) -> Vector{Int}

The output masks `b` for which the component `b·F` is bent (`|W_F(a,b)| = 2^{n/2}`
for all `a`). Empty when `n` is odd (no bent functions exist).

# Examples
```jldoctest
julia> using VBF

julia> isempty(bent_components(gold_apn(5, 1)))  # n = 5 is odd
true
```
"""
function bent_components(F::SBox{N, T}) where {N, T}
    isodd(N) && return Int[]
    L = lat(F)
    n = 1 << N
    target = 1 << (N ÷ 2)
    out = Int[]
    @inbounds for b in 0:n - 1
        bent = true
        for a in 0:n - 1
            if abs(L[a + 1, b + 1]) != target
                bent = false
                break
            end
        end
        bent && push!(out, b)
    end
    out
end

"""
    nonbent_components(F) -> Vector{Int}

The output masks `b` whose component `b·F` is *not* bent (includes `b = 0`). For
odd `n` this is every mask. A linear-equivalence invariant (as a set).
"""
function nonbent_components(F::SBox{N, T}) where {N, T}
    n = 1 << N
    isodd(N) && return collect(0:n - 1)
    bent = Set(bent_components(F))
    [b for b in 0:n - 1 if !(b in bent)]
end

"""
    nonbent_signature(F) -> Vector{Int}

The Gológlu nonbent signature: [`subspace_count_signature`](@ref) of the nonbent
component set — `[#nonbent∖{0}, #2-dim, #3-dim, …]`. A linear-equivalence
invariant (discriminating for even `n`).
"""
nonbent_signature(F::SBox{N, T}) where {N, T} = subspace_count_signature(nonbent_components(F), N)
